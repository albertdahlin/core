module IO exposing
    ( IO
    , succeed, fail, none
    , map, map2, map3, map4, andMap, mapError
    , andThen, recover
    , batch, sequence, concurrent
    , (|.), (|=)
    , print, sleep, exit
    , Future, async, await, spawnAsync
    , Address, send
    , Inbox, receive
    , Process
    , spawn
    , program
    , exitOnError, logOnError
    , addressOf, createInbox
    , sendTo, call, deferTo
    , spawnWorker
    , StateMachine, spawnStateMachine
    )

{-|


# Input / Output Primitives

An I/O value encapsulates an operation that
can either succeed of fail. Maybe you are familiar
with the [Promise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) class in javascript? This is the same idea.

@docs IO


## Create I/O values

@docs succeed, fail, none


## Transform I/O values

@docs map, map2, map3, map4, andMap, mapError


## Compose I/O values

@docs andThen, recover

@docs batch, sequence, concurrent
@docs (|.), (|=)


## Common Operations

@docs print, sleep, exit


## Async API

@docs Future, async, await, spawnAsync


# Concurrent I/O

This module uses the [Actor Model](https://en.wikipedia.org/wiki/Actor_model) to model concurrency.


## The Basic Stuff

An actor is a computational entity that, in response to a message it receives, can concurrently:

  - send a finite number of messages to other actors;
  - create a finite number of new actors;
  - designate the behavior to be used for the next message it receives (change its state).

There is no assumed sequence to the above actions and they could be carried out in parallel.

Recipients of messages are identified by address.
Thus an actor can only communicate with actors whose addresses it has.
It can obtain those from a message it receives,
or if the address is for an actor it has itself created.


## Send messages

A _Process_ is an _Actor_ that has been started (more on this below).

To send a message to a _Process_ you need its _Address_.
As you can see below, the _Address_ type has a variable (msg).
This will garantee that you only send messages to the Process that it will be able to understand.

@docs Address, send

Sending a message is a non-blocking operations.


## Receive a message

To receive a message you must have access to the _Inbox_
where the message is stored.
Each Process gets their own _Inbox_ (more on that below) when they are started.

@docs Inbox, receive


## Start a Process

A Process is an Actor that has been started (spawned).

A process is simply a function that takes an _Inbox_ as argument and returns I/O.

@docs Process

Let's create a simple process

    logger : Inbox String -> IO x ()
    logger inbox =
        receive inbox
            |> andThen print
            |> andThen (\_ -> logger inbox)

As you can see on the _IO_ type above, it has two parameters: `err` and `ok`.
This means that a _Process_ can exit in two ways:
Normally, or with failure

When that happens we should take care of this value somehow, right?
That's why you have to provide an address to which this result will be sent.

@docs spawn

After starting the actor you will get the Address to the inbox of the process
so you can send messages to it.

Here is a simple example of an actor:

    type Msg
        = Say String
        | Yell String

    speaker : Inbox Msg -> IO x ()
    speaker inbox =
        receive inbox
            |> andThen
                (\msg ->
                    case msg of
                        Say str ->
                            print str

                        Yell ->
                            print (String.toUpper str)
                )
            |> andThen (\_ -> speaker inbox)

This process will loop forever and:

1.  Wait for a message
2.  Print the message
3.  Repeat from 1


## Create a Program (main)

Now we can create a Program and use our actor.

@docs program

    helloWorld : Inbox () -> IO String ()
    helloWorld _ =
        spawn speaker exitOnError
            |> andThen
                (\speakerAddress ->
                    [ send (Say "Hello") speakerAddress
                    , send (Yell "World") speakerAddress
                    ]
                        |> batch
                )

    main : Program () () ()
    main =
        program helloWorld

If you look at the type signature of the `helloWorld` program
it might look familiar? It is also an Actor, right?

This is all the basics of concurrency in the actor model.
What follows is just convenience.


## Convenient Stuff

To make things simpler, this module provies two standard addresses
that you can use when spawning processes:

@docs exitOnError, logOnError
@docs addressOf, createInbox

@docs sendTo, call, deferTo


## Spawn variations

@docs spawnWorker


### Finite State Machine

@docs StateMachine, spawnStateMachine

-}

import Basics exposing (..)
import Dict exposing (Dict)
import Elm.Kernel.IO
import Internal.Cont as C
import Internal.ContWithResult as Cont exposing (Cont)
import List exposing ((::))
import Platform
import Result exposing (Result(..))
import String exposing (String)
import Tuple


infix left  0 (|.) = ignorer
infix left  0 (|=) = keeper


{-| -}
type alias IO err ok =
    Cont () err ok


{-| -}
type Inbox msg
    = Inbox


{-| -}
type Address msg
    = Address


{-| -}
type alias Process msg err ok =
    Inbox msg -> IO err ok



-- NATIVE KERNEL


{-| -}
print : String -> IO x ()
print =
    Elm.Kernel.IO.print


{-| -}
sleep : Float -> IO x ()
sleep =
    Elm.Kernel.IO.sleep


{-| -}
exit : Int -> IO x ()
exit =
    Elm.Kernel.IO.exit


{-| -}
program : (Inbox msg -> IO String ()) -> Platform.Program () () msg
program =
    Elm.Kernel.IO.program


{-| -}
spawn :
    Process msg err ok
    -> Address (Result err ok)
    -> IO x (Address msg)
spawn =
    Elm.Kernel.IO.spawn


{-| -}
receive : Inbox msg -> IO x msg
receive =
    Elm.Kernel.IO.recv


{-| -}
send : msg -> Address msg -> IO x ()
send =
    Elm.Kernel.IO.send


{-| Something that hasen't happened yet.
-}
type Future err ok
    = Future (Inbox (Result err ok))


{-| -}
async : IO err ok -> Future err ok
async =
    Elm.Kernel.IO.async


{-| -}
when : Future err ok -> Address (Result err ok) -> IO x ()
when future address =
    spawn (\_ -> await future) address
        |> map (\_ -> ())


{-| -}
createInbox : () -> IO err (Inbox msg)
createInbox =
    Elm.Kernel.IO.createInbox


{-| Get the address corresponding to an inbox.

    type MyMsg
        = GotValue Int

    inbox : Inbox MyMsg

Now I can do:

    returnAddress : Address MyMSg
    returnAddress =
        addressOf identity inbox

Or even better:

    returnAddress : Address Int
    returnAddress =
        addressOf GotValue inbox

-}
addressOf : (value -> msg) -> Inbox msg -> Address value
addressOf =
    Elm.Kernel.IO.addressOf


{-| Exits the program if an `Err` is received. The String will
be printed to `STDERR`.
-}
exitOnError : Address (Result String a)
exitOnError =
    Elm.Kernel.IO.exitOnError


{-| Print errors to `STDERR`.
-}
logOnError : Address (Result String a)
logOnError =
    Elm.Kernel.IO.logOnError



-- PURE STUFF


{-| -}
succeed : a -> IO x a
succeed =
    Cont.return


{-| -}
fail : err -> IO err a
fail =
    Cont.fail


{-| -}
map : (a -> b) -> IO x a -> IO x b
map =
    Cont.map


{-| -}
andThen : (a -> IO x b) -> IO x a -> IO x b
andThen =
    Cont.andThen


{-| -}
recover : (err -> IO x ok) -> IO err ok -> IO x ok
recover =
    Cont.recover


{-| -}
none : IO x ()
none =
    succeed ()


{-| -}
fromResult : Result err ok -> IO err ok
fromResult result =
    case result of
        Ok ok ->
            succeed ok

        Err err ->
            fail err


{-| -}
andMap : IO x a -> IO x (a -> b) -> IO x b
andMap ioa =
    andThen (\fn -> map (\a -> fn a) ioa)


{-| -}
map2 : (a -> b -> c) -> IO x a -> IO x b -> IO x c
map2 fn a b =
    succeed fn
        |> andMap a
        |> andMap b


{-| -}
map3 : (a -> b -> c -> d) -> IO x a -> IO x b -> IO x c -> IO x d
map3 fn a b c =
    succeed fn
        |> andMap a
        |> andMap b
        |> andMap c


{-| -}
map4 : (a -> b -> c -> d -> e) -> IO x a -> IO x b -> IO x c -> IO x d -> IO x e
map4 fn a b c d =
    succeed fn
        |> andMap a
        |> andMap b
        |> andMap c
        |> andMap d


{-| -}
mapError : (x -> y) -> IO x ok -> IO y ok
mapError fn =
    recover (\x -> fail (fn x))


{-| -}
batch : List (IO x ()) -> IO x ()
batch =
    List.foldl
        (\io -> andThen (\_ -> io))
        (succeed ())


{-| Keep the value from the row.

    example : IO x Int
    example =
        print "Hello"
            |= succeed 1
            |. print "World"

-}
keeper : IO x ignore -> IO x keep -> IO x keep
keeper ignore keep =
    andThen (\_ -> keep) ignore


{-| Keep the value from the row above.

    example : IO x Int
    example =
        succeed 1
            |. print "Hello"
            |. print "World"

-}
ignorer : IO x keep -> IO x ignore -> IO x keep
ignorer keep ignore =
    andThen (\k -> map (\_ -> k) ignore) keep


{-| Pipe-friendly version of send

    message
        |> sendTo address

-}
sendTo : Address msg -> msg -> IO err ()
sendTo addr msg =
    send msg addr


{-| Combine a list of IO one after the other.
-}
sequence : List (IO err ok) -> IO err (List ok)
sequence =
    List.foldl
        (\io ->
            andThen (\list -> map (\ok -> ok :: list) io)
        )
        (succeed [])
        >> map List.reverse


{-| -}
await : Future err ok -> IO err ok
await (Future inbox) =
    receive inbox
        |> andThen fromResult


{-|

    spawnAsync exitOnMsg
        |> andThen
            (\( address, exit ) ->
                send "Hello" address
                    |= await exit
                    |> andThen print
            )


    exitOnMsg : Inbox a -> IO x a
    exitOnMsg inbox =
        receive inbox

-}
spawnAsync :
    Process msg err ok
    -> IO x ( Address msg, Future err ok )
spawnAsync actor =
    createInbox ()
        |> andThen
            (\inbox ->
                spawn actor (addressOf identity inbox)
                    |> map (\addr -> ( addr, Future inbox ))
            )


{-| Combine a list of IO all at the same time.
-}
concurrent : List (IO err ok) -> IO err (List ok)
concurrent =
    List.map (async >> await)
        >> sequence


{-| Send a message and then wait for the reply.

    type Msg
        = SendValueTo (Address Int)
        | Increment

    getValue : Address Msg -> IO x Int
    getValue address =
        call SendValueTo address

-}
call : (Address value -> msg) -> Address msg -> IO x value
call toMsg addr =
    createInbox ()
        |> andThen
            (\inbox ->
                addressOf identity inbox
                    |> toMsg
                    |> sendTo addr
                    |> andThen (\_ -> receive inbox)
            )


{-| Defer an I/O action and send the result to an address.

    type Msg
        = GotResult (Result String Int)

    doSomethingSlow 1.0
        |> deferTo (addressOf GotResult inbox)
        |> continueDoingStuff


    doSomethingSlow : Float -> IO String Int

-}
deferTo : Address (Result err ok) -> IO err ok -> IO x ()
deferTo addr io =
    spawn (\_ -> io) addr
        |> map (\_ -> ())



-- ADRESSES
-- STATE MACHINE


{-| Implement actors with both state and IO. Looks familiar?

    type Msg
        = Increment
        | SendValueTo (Address Int)

    type alias Model =
        Int

    counter : StateMachine Int Model Msg x
    counter =
        { init = init
        , update = update
        }


    init : Int -> ( Model, IO x () )
    init arg =
        ( arg, succeed () )


    update : Msg -> Model -> ( Model, IO x () )
    update msg model =
        case msg of
            Increment ->
                ( model + 1
                , succeed ()
                )

            SendValueTo replyTo
                ( model
                , send model replyTo
                )

-}
type alias StateMachine args model msg err =
    { init : args -> ( model, IO err () )
    , update : msg -> model -> ( model, IO err () )
    }


{-| -}
spawnStateMachine :
    StateMachine args model msg err
    -> args
    -> Address (Result err ())
    -> IO x (Address msg)
spawnStateMachine sm args onExit =
    let
        ( model, io ) =
            sm.init args
    in
    io
        |> recover (\err -> send (Err err) onExit)
        |> andThen (\_ -> spawn (makeFSM sm.update model) onExit)


{-| -}
makeFSM :
    (msg -> model -> ( model, IO err () ))
    -> model
    -> Inbox msg
    -> IO err ()
makeFSM fn state inbox =
    receive inbox
        |> andThen
            (\msg ->
                let
                    ( state2, io ) =
                        fn msg state
                in
                andThen (\_ -> makeFSM fn state2 inbox) io
            )


{-| A worker is an actor that performs I/O but does not need any state.

Instead of doing this:

    speaker : Inbox Msg -> IO x ()
    speaker inbox =
        receive inbox
            |> andThen
                (\msg ->
                    case msg of
                        Say str ->
                            print str

                        Yell ->
                            print (String.toUpper str)
                )
            |> andThen (\_ -> speaker inbox)

you can just impelent the inner function:

    speaker : Msg -> IO x ()
    speaker msg =
        case msg of
            Say str ->
                print str

            Yell ->
                print (String.toUpper str)

-}
spawnWorker : (msg -> IO err ()) -> Address (Result err ()) -> IO x (Address msg)
spawnWorker fn onExit =
    spawn (makeWorker fn) onExit


{-| -}
makeWorker : (msg -> IO err ()) -> Inbox msg -> IO err ()
makeWorker fn inbox =
    receive inbox
        |> andThen fn
        |> andThen (\_ -> makeWorker fn inbox)
