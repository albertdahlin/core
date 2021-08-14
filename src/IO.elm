module IO exposing
    ( IO, return, fail
    , map, andThen, recover
    , print, sleep, exit, program
    , Address, send
    , Inbox, receive
    , Process
    , spawn
    , exitOnError, logOnError
    , addressOf, createInbox
    , sendTo, call, deferTo
    , spawnWorker
    , StateMachine, spawnStateMachine
    )

{-|


# IO Primitives


## Create I/O

@docs IO, return, fail


## Transform and Compose I/O

@docs map, andThen, recover


## Common Operations

@docs print, sleep, exit, program


# Concurrent IO

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

To send a message to a _Process_ you need its _Address_.
As you can see below, the _Address_ type has a variable (msg).
This will garantee that you only send messages to the Process that it will be able to understand.

@docs Address, send


## Receive a message

To receive a message you must have access to the _Inbox_
where the message is stored.
Each Process gets their own _Inbox_ (more on that below) when they are started.

@docs Inbox, receive


## Start a Process

A Process is an Actor that has been started (spawned).

To start an Actor we need two things:

  - An _Actor_ (obviously).
  - An _Address_ where we can send the Result if the process terminates.

A process is simply a function that takes an _Inbox_ as argument and returns I/O.

@docs Process

As you can see on the _IO_ type above, it has two parameters: `err` and `ok`.
This means that a _Process_ can exit in two ways:
Normally, or with failure. When that happens the result will be sent
to the address that you provieded.

@docs spawn

After starting the actor you will get the Address to the inbox of the process
so you can send messages to it.

To make things simpler, this module provies two standard addresses
that you can use when spawning processes:

@docs exitOnError, logOnError

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


## Convenient Stuff

@docs addressOf, createInbox

@docs sendTo, call, deferTo


## Spawn variations

@docs spawnWorker


### Finite State Machine

@docs StateMachine, spawnStateMachine

-}

import Basics exposing (..)
import Elm.Kernel.IO
import Platform
import Result exposing (Result(..))
import String exposing (String)


{-| -}
type IO err ok
    = IO


{-| -}
type Inbox msg
    = Inbox


{-| -}
type Address msg
    = Address


{-| -}
return : a -> IO x a
return =
    Elm.Kernel.IO.return


{-| -}
fail : err -> IO err a
fail =
    Elm.Kernel.IO.fail


{-| -}
map : (a -> b) -> IO x a -> IO x b
map =
    -- This is not a misstake, it explits how Promis.then works.
    Elm.Kernel.IO.andThen


{-| -}
andThen : (a -> IO x b) -> IO x a -> IO x b
andThen =
    Elm.Kernel.IO.andThen


{-| -}
recover : (err -> IO x ok) -> IO err ok -> IO x ok
recover =
    Elm.Kernel.IO.recover


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
program : (() -> IO String ()) -> Platform.Program () () ()
program =
    Elm.Kernel.IO.program



-- ACTOR


{-| -}
type alias Process msg err ok =
    Inbox msg -> IO err ok


{-| -}
spawn :
    Process msg err ok
    -> Address (Result err ok)
    -> IO x (Address msg)
spawn =
    Elm.Kernel.IO.spawnLink


{-| -}
receive : Inbox msg -> IO x msg
receive =
    Elm.Kernel.IO.recv


{-| -}
send : msg -> Address msg -> IO x ()
send =
    Elm.Kernel.IO.send


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


{-| Pipe-friendly version of send

    message
        |> sendTo address

-}
sendTo : Address msg -> msg -> IO err ()
sendTo addr msg =
    send msg addr


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
        ( arg, return () )


    update : Msg -> Model -> ( Model, IO x () )
    update msg model =
        case msg of
            Increment ->
                ( model + 1
                , return ()
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
