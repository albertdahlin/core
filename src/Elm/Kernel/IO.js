/*

*/

var inboxes = new WeakMap();
var resolvers = new WeakMap();


var _IO_return = Promise.resolve;
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
    setTimeout(fn, 0, inbox);

    return Promise.resolve(inbox);
}

function _IO_recv(inbox) {
    var msg = inboxes.get(inbox.key).shift();

    if (msg) {
        return Promise.resolve(msg);
    } else {
        return new Promise(resolve =>
            resolvers.get(inbox.key).push(resolve)
        );
    }
}

var _IO_send = F2(function(msg, address) {
    var resolve = resolvers.get(address.key).shift();
    var tagger = address.tagger || function(x) { return x };

    if (resolve) {
        resolve(tagger(msg));
    } else {
        inboxes.get(address.key).push(tagger(msg));
    }

    return Promise.resolve(null);
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
    console.log('program impl', impl);
});

function _Platform_export(p) {
    console.log('export', p);
}
