/*
import Result exposing (Ok, Err, isOk, isErr)
import IO exposing (succeed, andThen, deferTo, Future, Inbox, Address, spawn)
import Elm.Kernel.Utils exposing (Tuple0)

*/

var inboxes = new WeakMap();
var waitingForMsg = new WeakMap();
var lastKey = 0

function _IO_print(m) {
    return function(continuation) {
        console.log(m);
        continuation(__Result_Ok(__Utils_Tuple0));
    }
 }

function _IO_sleep(t) {
    return function(continuation) {
        setTimeout(continuation, t, __Result_Ok(__Utils_Tuple0));
    }
}


function _IO_exit(status) {
    process.exit(status);
}

var _IO_spawn = F2(IO_spawn);
function IO_spawn(io, onExit) {
    setTimeout(function() {
        io(function(res) { IO_send(res, onExit) })
    }, 0);

    return __IO_succeed(__Utils_Tuple0);
}


function _IO_recv(address) {
    return function(continuation) {
        var inbox = inboxes.get(address.key);
        var msg = inbox && inbox.shift();

        if (msg) {
            continuation(__Result_Ok(msg));
        } else {
            var waiting = waitingForMsg.get(address.key)
            waiting.push(continuation);
        }
    }
}


var _IO_send = F2(IO_send);
function IO_send(msg, address) {
    if (address.handler) {
        return address.handler(msg);
    }

    var waiting = waitingForMsg.get(address.key);
    var tagger  = address.tagger || function(x) { return x };
    var continuation = waiting && waiting.shift();

    if (continuation) {
        continuation(__Result_Ok(tagger(msg)));
    } else {
        var inbox = inboxes.get(address.key);

        if (typeof inbox !== 'undefined') {
            inbox.push(tagger(msg));
        }
    }

    return __IO_succeed(__Utils_Tuple0);
};


function _IO_createInbox() {
    return __IO_succeed(IO_createInbox())
}
function IO_createInbox() {
    var address = {
        key: {},
        id: lastKey++
    };
    inboxes.set(address.key, []);
    waitingForMsg.set(address.key, []);

    return __IO_Inbox(address);
}


var _IO_addressOf = F2(function(tagger, inbox) {
    return __IO_Address({
        id: inbox.id,
        key: inbox.key,
        tagger: tagger
    })
});


var IO_exitOnError = {
    handler: function(msg) {
        if (!__Result_isOk(msg)) {
            console.error('error', msg.a);
            _IO_exit(-1);
        }
    }
};

var _IO_program = F4(function(impl, flagDecoder, debugMetadata, args) {
    var onExit = __IO_Address(IO_exitOnError);
    var inbox = IO_createInbox();
    IO_spawn(impl(inbox), onExit);
});

function _Platform_export(p) {
    p.Test.init(process);
}
