/*

*/

var inboxes = new WeakMap();
var resolvers = new WeakMap();


//var _IO_return = Promise.resolve;
function _IO_return(v) {
    return Promise.resolve(v);
}
var _IO_fail = Promise.reject;
var _IO_print = console.log

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

function _IO_spawn(fn) {
    var inbox = {
        key: {}
    };
    inboxes.set(inbox.key, []);
    resolvers.set(inbox.key, []);
    var wrapIo = function() {
        var io = fn(inbox);
        io.finally(x => {
            inboxes.delete(inbox.key);
            resolvers.delete(inbox.key);
        });

        return io;
    }
    setTimeout(wrapIo, 0, inbox);

    return Promise.resolve(inbox);
}

var _IO_spawnLink = F2(function(fn, linkTo) {
    var inbox = {
        key: {}
    };
    inboxes.set(inbox.key, []);
    resolvers.set(inbox.key, []);
    var wrapIo = function() {
        var io = fn(inbox);
        io.finally(x => {
            inboxes.delete(inbox.key);
            resolvers.delete(inbox.key);
        });

        return io;
    }
    setTimeout(wrapIo, 0, inbox);

    return Promise.resolve(inbox);
});

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


var _IO_program = F4(function(impl, flagDecoder, debugMetadata, args) {
    impl(process)
        .catch(err => console.error('ERROR', err));
});

function _Platform_export(p) {
    p.Test.init(process);
}
