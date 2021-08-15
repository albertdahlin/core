/*
import Result exposing (Ok, Err, isOk, isErr)
import IO exposing (succeed, andThen, deferTo, Future, Inbox, Address, spawn)

*/

var inboxes = new WeakMap();
var resolvers = new WeakMap();
var lastKey = 0

function _IO_print(m) {
    return function(cont) {
        console.log(m);
        cont(__Result_Ok(0));
    }
 }

function _IO_sleep(t) {
    return function(cont) {
        setTimeout(cont, t, __Result_Ok(0));
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

    return __IO_succeed(0);
}


function _IO_recv(inbox) {
    return function(cont) {
        var msg = inboxes.get(inbox.key).shift();

        if (msg) {
            cont(__Result_Ok(msg));
        } else {
            var r = resolvers.get(inbox.key)
            r.push(cont);
        }
    }
}


var _IO_send = F2(IO_send);
function IO_send(msg, address) {
    if (address.handler) {
        return address.handler(msg);
    }

    var resolver = resolvers.get(address.key);
    var tagger  = address.tagger || function(x) { return x };
    var resolve = resolver && resolver.shift();

    if (resolve) {
        resolve(__Result_Ok(tagger(msg)));
    } else {
        var inbox = inboxes.get(address.key);

        if (typeof inbox !== 'undefined') {
            inbox.push(tagger(msg));
        }
    }

    return __IO_succeed(0);
};


function _IO_createInbox() {
    return __IO_succeed(IO_createInbox())
}
function IO_createInbox() {
    var inbox = {
        key: {},
        id: lastKey++
    };
    inboxes.set(inbox.key, []);
    resolvers.set(inbox.key, []);

    return __IO_Inbox(inbox);
}


var _IO_addressOf = F2(function(tagger, inbox) {
    return __IO_Address({
        id: inbox.id,
        key: inbox.key,
        tagger: tagger
    })
});


var _IO_exitOnError = {
    handler: function(msg) {
        if (!__Result_isOk(msg)) {
            console.error('error', msg.a);
            _IO_exit(-1);
        }
    }
};
var _IO_logOnError = {
    handler: function(msg) {
        if (!__Result_isOk(msg)) {
            console.error(msg.a);
        }
        return __IO_succeed(0);
    }
};

var _IO_program = F4(function(impl, flagDecoder, debugMetadata, args) {
    var onExit = __IO_Address(_IO_exitOnError);
    var inbox = IO_createInbox();
    IO_spawn(impl(inbox), onExit);
});

function _Platform_export(p) {
    p.Test.init(process);
}
