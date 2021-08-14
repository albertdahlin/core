/*
import Result exposing (Ok, Err, isOk, isErr)
import IO exposing (succeed)

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

var _IO_spawn = F2(spawnLink);

function spawnLink(actor, linkTo) {
    var inbox = {
        key: {},
        id: lastKey++
    };
    inboxes.set(inbox.key, []);
    resolvers.set(inbox.key, []);

    setTimeout(function() {
        actor(inbox)(function(res) { A2(_IO_send, res, linkTo) })
    }, 0);

    return __IO_succeed(inbox);
}

function _IO_async(io) {
    return function(cont) {
        setTimeout(cont, 0, io)
    }
}

function _IO_await(io) {
}


function _IO_recv(inbox) {
    var msg = inboxes.get(inbox.key).shift();

    if (msg) {
        return __IO_succeed(msg);
    } else {
        var r = resolvers.get(inbox.key)
        return function(cont) {
            r.push(cont);
        }
    }
}

var _IO_send = F2(function(msg, address) {
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
});

function _IO_createInbox() {
    var inbox = {
        key: {},
        id: lastKey++
    };
    inboxes.set(inbox.key, []);
    resolvers.set(inbox.key, []);

    return __IO_succeed(inbox);
}

var _IO_addressOf = F2(function(tagger, inbox) {
    return {
        id: inbox.id,
        key: inbox.key,
        tagger: tagger
    }
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
    spawnLink(impl, _IO_exitOnError);
});

function _Platform_export(p) {
    p.Test.init(process);
}
