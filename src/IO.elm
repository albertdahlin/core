module IO exposing
    ( IO, return, fail
    , andThen, and, recover
    , print, sleep
    , program
    , Address, Inbox
    , spawn
    , send, receive
    , addressOf, createInbox
    , sendTo, call, spawnLink
    , StateMachine, spawnStateMachine
    )

{-|


# IO Primitives

@docs IO, return, fail
@docs andThen, and, recover
@docs print, sleep
@docs program


# Concurrent IO

Concurrent IO using the Actor Model


## The Basic Stuff

The actor model adopts the philosophy that everything is an actor. This is similar to the everything is an object philosophy used by some object-oriented programming languages.

An actor is a computational entity that, in response to a message it receives, can concurrently:

  - send a finite number of messages to other actors;
  - create a finite number of new actors;
  - designate the behavior to be used for the next message it receives.

There is no assumed sequence to the above actions and they could be carried out in parallel.

Decoupling the sender from communications sent was a fundamental advance of the actor model enabling asynchronous communication and control structures as patterns of passing messages.

Recipients of messages are identified by address, sometimes called "mailing address". Thus an actor can only communicate with actors whose addresses it has. It can obtain those from a message it receives, or if the address is for an actor it has itself created.

The actor model is characterized by inherent concurrency of computation within and among actors, dynamic creation of actors, inclusion of actor addresses in messages, and interaction only through direct asynchronous message passing with no restriction on message arrival order.

@docs Address, Inbox


### Spawn a process (Actor)

@docs spawn


### Send & Receive messages

@docs send, receive


### Address & Inbox

@docs addressOf, createInbox


## Convenient Stuff

@docs sendTo, call, spawnLink
@docs StateMachine, spawnStateMachine

-}

import Basics exposing (..)
import Elm.Kernel.IO
import Platform
import Result exposing (Result)
import String exposing (String)


{-| -}
type IO err ok
    = IO


{-| An inbox where you can retrieve messages from.
-}
type Inbox msg
    = Inbox


{-| An Address of an `Inbox` that you can send messages to.
-}
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
andThen : (a -> IO x b) -> IO x a -> IO x b
andThen =
    Elm.Kernel.IO.andThen


{-| -}
and : IO x b -> IO x a -> IO x b
and b a =
    andThen (\_ -> b) a


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
program : (() -> IO String ()) -> Platform.Program () () ()
program =
    Elm.Kernel.IO.program



-- ACTOR


{-| -}
spawn : (Inbox msg -> IO err ()) -> IO x (Address msg)
spawn =
    Elm.Kernel.IO.spawn


{-| -}
spawnLink :
    (Inbox msg -> IO err ok)
    -> Address (Result err ok)
    -> IO x (Address msg)
spawnLink =
    Elm.Kernel.IO.spawnLink


{-| -}
receive : Inbox msg -> IO err msg
receive =
    Elm.Kernel.IO.recv


{-| -}
send : msg -> Address msg -> IO err ()
send =
    Elm.Kernel.IO.send


{-| -}
createInbox : () -> IO err (Inbox msg)
createInbox =
    Elm.Kernel.IO.createInbox


{-| -}
addressOf : (v -> msg) -> Inbox msg -> Address v
addressOf =
    Elm.Kernel.IO.addressOf


{-| -}
sendTo : Address msg -> msg -> IO err ()
sendTo addr msg =
    send msg addr


{-| -}
call : (Address v -> msg) -> Address msg -> IO err v
call toMsg addr =
    createInbox ()
        |> andThen
            (\inbox ->
                addressOf identity inbox
                    |> toMsg
                    |> sendTo addr
                    |> andThen (\_ -> receive inbox)
            )



-- STATE MACHINE


{-| -}
type alias StateMachine args model msg =
    { init : args -> ( model, IO String () )
    , update : msg -> model -> ( model, IO String () )
    }


{-| -}
spawnStateMachine :
    StateMachine args model msg
    -> args
    -> IO String (Address msg)
spawnStateMachine sm args =
    let
        ( model, io ) =
            sm.init args
    in
    andThen (\_ -> spawn (makeActor sm.update model)) io


{-| -}
makeActor :
    (msg -> model -> ( model, IO String () ))
    -> model
    -> Inbox msg
    -> IO String ()
makeActor fn state inbox =
    receive inbox
        |> andThen
            (\msg ->
                let
                    ( state2, io ) =
                        fn msg state
                in
                andThen (\_ -> makeActor fn state2 inbox) io
            )
