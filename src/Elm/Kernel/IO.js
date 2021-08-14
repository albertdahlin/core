/*
import Result exposing (Ok, Err, isOk, isErr)

*/

var inboxes = new WeakMap();
var resolvers = new WeakMap();

function _IO_return(v) { return Promise.resolve(v); }
function _IO_fail(e) { return Promise.reject(e); }
function _IO_print(m) { console.log(m); return _IO_return(0); }

function _IO_sleep(t) {
    return new Promise(resolve => setTimeout(resolve, t));
}

var _IO_andThen = F2(function(fn, io)
{
    return io.then(fn);
});

var _IO_recover = F2(function(fn, io)
{
    return io.catch(fn);
});

function _IO_exit(status) {
    process.exit(status);
}

var _IO_spawn = F2(spawnLink);

function spawnLink(fn, linkTo) {
    var inbox = {
        key: {}
    };
    inboxes.set(inbox.key, []);
    resolvers.set(inbox.key, []);
    var wrapIo = function() {
        var io = Promise.resolve(inbox).then(fn);

        io = io
            .then(ok => A2(_IO_send, __Result_Ok(ok), linkTo))
            .catch(err => A2(_IO_send, __Result_Err(err), linkTo))
            .finally(x => {
                inboxes.delete(inbox.key);
                resolvers.delete(inbox.key);
        });

        return io;
    }
    setTimeout(wrapIo, 0, inbox);

    return Promise.resolve(inbox);
}

function _IO_recv(inbox) {
    var msg = inboxes.get(inbox.key).shift();

    if (msg) {
        return Promise.resolve(msg);
    } else {
        var r = resolvers.get(inbox.key)
        return new Promise(resolve => r.push(resolve));
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
        resolve(tagger(msg));
    } else {
        var inbox = inboxes.get(address.key);

        if (typeof inbox !== 'undefined') {
            inbox.push(tagger(msg));
        }
    }

    return Promise.resolve(0);
});

function _IO_createInbox(a) {
    var inbox = {
        key: {}
    };
    inboxes.set(inbox.key, []);
    resolvers.set(inbox.key, []);

    return Promise.resolve(inbox);
}

var _IO_addressOf = F2(function(tagger, inbox) {
    return {
        key: inbox.key,
        tagger: tagger
    }
});


var _IO_exitOnError = {
    handler: function(msg) {
        if (!__Result_isOk(msg)) {
            console.error(msg.a);
            _IO_exit(-1);
        }
    }
};
var _IO_logOnError = {
    handler: function(msg) {
        if (!__Result_isOk(msg)) {
            console.error(msg.a);
        }
        return _IO_return(0);
    }
};

var _IO_program = F4(function(impl, flagDecoder, debugMetadata, args) {
    spawnLink(impl, _IO_exitOnError);
});

function _Platform_export(p) {
    p.Test.init(process);
}
