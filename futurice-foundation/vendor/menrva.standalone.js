!function(e){if("object"==typeof exports&&"undefined"!=typeof module)module.exports=e();else if("function"==typeof define&&define.amd)define([],e);else{var f;"undefined"!=typeof window?f=window:"undefined"!=typeof global?f=global:"undefined"!=typeof self&&(f=self),f.menrva=e()}}(function(){var define,module,exports;return (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
/*
 * menrva
 * https://github.com/phadej/menrva
 *
 * Copyright (c) 2014 Oleg Grenrus
 * Licensed under the MIT license.
 */

"use strict";

var signal = require("./signal.js");
var util = require("./util.js");

/**
  ### Convenience methods

  #### signal.log

  > signal.log (@ : Signal a, args...) : Unsubscriber

  Essentially `signal.onValue(console.log.bind(console, args...))
*/
signal.Signal.prototype.log = function () {
  var args = Array.prototype.slice.call(arguments);
  return this.onValue(function (x) {
    var logArgs = args.concat([x]);
    console.log.apply(console, logArgs);
  });
};

/**
  #### signal.onSpread

  > signal.onSpread (@ : Signal [a, b...], callback : a -> b ... -> void) : Unsubscriber

  `onValue` with signal's tuple arguments spread.
*/
signal.Signal.prototype.onSpread = function (callback) {
  return this.onValue(function (t) {
    callback.apply(undefined, t);
  });
};

/**
  #### tuple

  > tuple (x : Signal a, y : Signal b...) : Signal [a, b...]

  Combine signals into tuple.
*/

function tuple() {
  var signals = Array.prototype.slice.call(arguments);
  var mapped = new (signal.CombinedSignal)(signals, util.identity);

  // connect to parent
  signals.forEach(function (parent) {
    parent.children.push(mapped);
  });

  return mapped;
}

/**
  #### sequence

  > sequence [Signal a, Signal b, ..] : Signal [a, b...]

  In promise libraries this might be called `all`.
*/
function sequence(signals) {
  var mapped = new (signal.CombinedSignal)(signals, util.identity);

  // connect to parent
  signals.forEach(function (parent) {
    parent.children.push(mapped);
  });

  return mapped;
}

/**
  #### record

  > record {k: Signal a, l: Signal b...} : Signal {k: a, l: b...}

  Like `sequence` but for records i.e. objects.
*/

function record(rec) {
  var keys = [];
  var signals = [];

  for (var k in rec) {
    // if (Object.prototype.hasOwnProperty.call(rec, k)) {
    keys.push(k);
    signals.push(rec[k]);
    // }
  }

  function toObject(values) {
    var res = {};

    for (var i = 0; i < keys.length; i++) {
      res[keys[i]] = values[i];
    }

    return res;
  }

  var mapped = new (signal.CombinedSignal)(signals, toObject);

  // connect to parent
  signals.forEach(function (parent) {
    parent.children.push(mapped);
  });

  return mapped;
}

module.exports = {
  tuple: tuple,
  sequence: sequence,
  record: record,
};

},{"./signal.js":6,"./util.js":8}],2:[function(require,module,exports){
/*
 * menrva
 * https://github.com/phadej/menrva
 *
 * Copyright (c) 2014 Oleg Grenrus
 * Licensed under the MIT license.
 */

"use strict";

/**
	### Equalities

	#### egal

	> egal (a, b) : boolean

	Identity check. `Object.is`. http://wiki.ecmascript.org/doku.php?id=harmony:egal
*/
function egal(a, b) {
	if (a === 0 && b === 0) {
		return 1/a === 1/b;
	} else if (a !== a) {
		return b !== b;
	} else {
		return a === b;
	}
}

module.exports = egal;

},{}],3:[function(require,module,exports){
/*
 * menrva
 * https://github.com/phadej/menrva
 *
 * Copyright (c) 2014 Oleg Grenrus
 * Licensed under the MIT license.
 */

"use strict";

var util = require("./util.js");
var signal = require("./signal.js");

/**
  ### Lens

  Lenses are composable functional references.
  They allow you to *access* and *modify* data potentially very deep within a structure!
*/
function Lens(parent, path, eq) {
  this.parents = [parent];
  this.path = path.split(/\./);
  var value = this.calculate();
  signal.initSignal(this, value, eq);
}

Lens.prototype = new signal.Signal();

Lens.prototype.calculateRank = function () {
  return this.parents[0].rank + 1;
};

Lens.prototype.calculate = function () {
  return util.getPath(this.parents[0].v, this.path);
};

/**
  #### source.zoom

  > zoom (@ : Source a, path : Path a b, eq = egal : b -> b -> boolean) : Source b

  Zoom (or focus) into part specified by `path` of the original signal.
  One can `set` and `modify` zoomed signals, they act as sources.

  ```js
  var quux = source.zoom("foo.bar.quux");
  ```
*/
signal.Source.prototype.zoom = Lens.prototype.zoom = function(f, eq) {
  var mapped = new Lens(this, f, eq);
  this.children.push(mapped);
  return mapped;
};

Lens.prototype.set = function (tx, value) {
  var path = this.path;
  this.parents[0].modify(tx, function (obj) {
    return util.setPath(obj, path, value);
  });
};

Lens.prototype.modify = function (tx, f) {
  var path = this.path;
  this.parents[0].modify(tx, function (obj) {
    return util.modifyPath(obj, path, f);
  });
};

},{"./signal.js":6,"./util.js":8}],4:[function(require,module,exports){
/*
 * menrva
 * https://github.com/phadej/menrva
 *
 * Copyright (c) 2014 Oleg Grenrus
 * Licensed under the MIT license.
 */

/**
# menrva

<!-- README.md is autogenerated -->

[![Build Status](https://secure.travis-ci.org/phadej/menrva.svg?branch=master)](http://travis-ci.org/phadej/menrva)
[![NPM version](http://img.shields.io/npm/v/menrva.svg)](https://www.npmjs.org/package/menrva)
[![Dependency Status](https://david-dm.org/phadej/menrva.svg)](https://david-dm.org/phadej/menrva)
[![devDependency Status](https://david-dm.org/phadej/menrva/dev-status.svg)](https://david-dm.org/phadej/menrva#info=devDependencies)
[![Coverage Status](https://img.shields.io/coveralls/phadej/menrva.svg)](https://coveralls.io/r/phadej/menrva?branch=master)
[![Code Climate](http://img.shields.io/codeclimate/github/phadej/menrva.svg)](https://codeclimate.com/github/phadej/menrva)

Ambitious data-flow library.

## Getting Started
Install the module with: `npm install menrva`

```js
var menrva = require('menrva');
menrva.some('awe'); // some, as in awesome?
```

## API
*/
/// include signal.js
/// include transaction.js
/// include lens.js
/// include convenience.js
/// include egal.js
/// include option.js
/**
## Contributing
*/
/// plain ../CONTRIBUTING.md
/**
## Release History
*/
/// plain ../CHANGELOG.md
/**

## License

Copyright (c) 2014 Oleg Grenrus.
Licensed under the MIT license.
*/

"use strict";

var egal = require("./egal.js");
var option = require("./option.js");
var signal = require("./signal.js");
var transaction = require("./transaction.js");

// extensions
require("./lens.js");
var convenience = require("./convenience.js");

// version
var version = "0.0.7";

module.exports = {
  egal: egal,
  some: option.some,
  none: option.none,
  Signal: signal.Signal,
  source: signal.source,
  combine: signal.combine,
  tuple: convenience.tuple,
  sequence: convenience.sequence,
  record: convenience.record,
  transaction: transaction,
  version: version,
};

},{"./convenience.js":1,"./egal.js":2,"./lens.js":3,"./option.js":5,"./signal.js":6,"./transaction.js":7}],5:[function(require,module,exports){
/*
 * menrva
 * https://github.com/phadej/menrva
 *
 * Copyright (c) 2014 Oleg Grenrus
 * Licensed under the MIT license.
 */

"use strict";

var egal = require("./egal.js");
var util = require("./util.js");

// typify: instance Option
// Option type

/**
  ### Option

  Also known as `Maybe`.
*/
function Option() {}

// Some
function Some(x) {
  this.value = x;
}

Some.prototype = new Option();

function some(x) {
  return new Some(x);
}

// None
function None() {}

None.prototype = new Option();

var none = new None();

// Methods

/**
  #### option.equals

  > equals (@ : option a, other : *, eq = eqal : a -> a -> boolean) : boolean

  Equality check.
*/
Some.prototype.equals = function (other, eq) {
  eq = eq || egal;
  return other instanceof Some && eq(this.value, other.value); // TODO: use egal
};

None.prototype.equals = function (other) {
  // only one instance of `none`
  return this === other;
};

/**
  #### option.map

  > map (@ : option a, f : a -> b) : option b
*/
// :: fn -> Option
Some.prototype.map = function (f) {
  return some(f(this.value));
};

// :: fn -> Option
None.prototype.map = function (f) {
  return none;
};

/**
  #### option.elim

  > elim (@ : option a, x : b, f : a -> b) : b

*/
Some.prototype.elim = function (x, f) {
  return f(this.value);
};

None.prototype.elim = function (x, f) {
  return x;
};

/**
  #### option.orElse

  > orElse (@ : option a, x : a) : a
*/
Option.prototype.orElse = function (x) {
  return this.elim(x, util.identity);
};

module.exports = {
  some: some,
  none: none,
};

},{"./egal.js":2,"./util.js":8}],6:[function(require,module,exports){
/*
 * menrva
 * https://github.com/phadej/menrva
 *
 * Copyright (c) 2014 Oleg Grenrus
 * Licensed under the MIT license.
 */

"use strict";

var egal = require("./egal.js");
var util = require("./util.js");

/**
  ### Signal

  The core type of menrva. `Signal` is abstract class, and cannot be created explicitly.

  Similar concepts are: *Behaviours* in FRP, *Properties* in bacon.js.

  You can add methods to `Signal`'s prototype. They will be available on all signals.
*/
function Signal() {}

// Each signal has an unique index.
var index = 0;

function initSignal(signal, value, eq) {
  signal.children = [];
  signal.callbacks = [];
  signal.v = value;

  // `index` is used to implement faster sets of signals
  signal.index = index++;

  // `rank` is used to sort signals topologically
  signal.rank = signal.calculateRank();

  // `eq` is an equality decision function on the signal values
  signal.eq = eq || egal;
}

function CombinedSignal(parents, f, eq) {
  this.parents = parents;
  this.f = f;
  var value = this.calculate();
  initSignal(this, value, eq);
}

CombinedSignal.prototype = new Signal();

// rank of combined signal is 1 + maximum rank of parents
CombinedSignal.prototype.calculateRank = function () {
  return Math.max.apply(Math, util.pluck(this.parents, "rank")) + 1;
};

CombinedSignal.prototype.calculate = function () {
  return this.f.call(undefined, util.pluck(this.parents, "v"));
};

/**
  #### signal.map

  > map (@ : Signal a, f : a -> b, eq = egal : b -> b -> boolean) : Signal b
*/
Signal.prototype.map = function(f, eq) {
  var mapped = new CombinedSignal([this], function (xs) {
   return f(xs[0]);
  }, eq);
  this.children.push(mapped);
  return mapped;
};

/**
  #### signal.onValue

  > onValue (@ : Signal a, callback : a -> void) -> Unsubscriber

  Add value callback. `callback` is immediately executed with the current value of signal.
  After than `callback` will be called, each time signal's value changes.

  The return value is a function, which will remove the callback if executed.
*/
Signal.prototype.onValue = function (callback) {
  // we wrap callback in function, to make it unique
  var wrapped = function (x) { callback(x); };

  // add to callbacks list
  this.callbacks.push(wrapped);

  // execute the callback *synchronously*
  callback(this.v);

  // return unsubscriber
  var that = this;
  return function () {
    var index = that.callbacks.indexOf(wrapped);
    if (index !== -1) {
      that.callbacks.splice(index, 1);
    }
  };
};

/**
  #### signal.value()

  > value (@ : Signal a): Signal a

  Returns the current value of signal.
*/
Signal.prototype.value = function() {
  return this.v;
};

/**
  ### Source

  A signal which value you can set.

  Similar concepts are: *Bacon.Model* in bacon.js, *BehaviourSubject* in Rx.


  #### source

  > source (initialValue : a, eq = egal : a -> a -> boolean) : Source a
*/
function Source(initialValue, eq) {
  initSignal(this, initialValue, eq);
}

function source(initialValue, eq) {
  return new Source(initialValue, eq);
}

Source.prototype = new Signal();

Source.prototype.calculateRank = function () {
  return 0;
};

/**
  #### source.set

  > set (@ : Source a, tx : Transaction, value : a) : void
*/
Source.prototype.set = function (transaction, value) {
  transaction.addAction({
    type: "set",
    signal: this,
    value: value,
  });
};

/**
  #### source.modify

  > modify (@ : Source a, tx : Transaction, f : a -> a) : void

  Mofify source value. `f` will be called with current value of signal inside the transaction.
*/
Source.prototype.modify = function (transaction, f) {
  transaction.addAction({
    type: "modify",
    signal: this,
    f: f,
  });
};


/**
  ### Signal combinators
*/

/**
  #### combine

  > combine (Signal a..., f : a... -> b) : Signal b

  Applicative n-ary lift. Lift pure function to operate on signals:
  ```js
  var $sum = menrva.combine($a, $b, function (a, b) {
    return a + b;
  });
  ```
*/
function combine() {
  var signals = Array.prototype.slice.call(arguments, 0, -1);
  var f = arguments[arguments.length - 1];

  var mapped = new CombinedSignal(signals, function (values) {
    return f.apply(undefined, values);
  });

  // connect to parent
  signals.forEach(function (parent) {
    parent.children.push(mapped);
  });

  return mapped;
}

module.exports = {
  Signal: Signal,
  Source: Source,
  source: source,
  combine: combine,
  initSignal: initSignal,
  // Internal:
  CombinedSignal: CombinedSignal,
};

},{"./egal.js":2,"./util.js":8}],7:[function(require,module,exports){
/*
 * menrva
 * https://github.com/phadej/menrva
 *
 * Copyright (c) 2014 Oleg Grenrus
 * Licensed under the MIT license.
 */

"use strict";

var util = require("./util.js");

/**
  ### Transaction

  One gathers atomic updates into single transaction (to avoid glitches).

  ```js
  var tx = menrva.transaction();
  sourceA.set(tx, 42);
  sourceB.modify(tx, function (x) { return x + x; });
  tx.commit(); // not necessary, transactions are auto-commited
  ```

  There are also optional syntaxes for simple transactions:
  ```js
  menrva.transaction()
    .set(sourceA, 42)
    .modify(sourceB, function (x) { return x + x; })
    .commit();
  ```
  or even
  ```js
  menrva.transaction([sourceA, 42, sourceB, function(x) { return x + x; }]).commit();
  ```
*/
function Transaction() {
  this.actions = [];
  this.commitScheduled = false;
}

/**
  #### transaction

  > transaction (facts) : Transaction

  Create transaction.

  Shorthand syntax:

  > transaction ([sourceA, valueA, sourceB, valueB ...]) : Transaction

  If `value` is function, `source.modify(tx, value)` is called; otherwise `source.set(tx, value)`.
*/
function transaction(facts) {
  var tx = new Transaction();

  if (Array.isArray(facts)) {
    var len = facts.length;
    for (var i = 0; i < len; i += 2) {
      var source = facts[i];
      var value = facts[i + 1];
      if (typeof value === "function") {
        source.modify(tx, value);
      } else {
        source.set(tx, value);
      }
    }
  }

  return tx;
}

/**
  #### transaction.commit

  Commit the transaction, forcing synchronous data propagation.
*/

function calculateUpdates(actions) {
  var updates = {};
  var len = actions.length;
  for (var i = 0; i < len; i++) {
    var action = actions[i];
    // find update fact for signal
    var update = updates[action.signal.index];

    // if not update found, create new for action's signal
    if (!update) {
      update = {
        signal: action.signal,
        value: action.signal.v,
      };
      updates[action.signal.index] = update;
    }

    // perform action
    switch (action.type) {
      case "set":
        update.value = action.value;
        break;
      case "modify":
        update.value = action.f(update.value);
        break;
    }
  }

  return util.values(updates);
}

function initialSet(updates) {
  var updated = [];
  var len = updates.length;
  for (var i = 0; i < len; i++) {
    var update = updates[i];
    // if different value
    if (!update.signal.eq(update.signal.v, update.value)) {
      // set it
      update.signal.v = update.value;

      // collect updated source signal
      updated.push(update.signal);
    }
  }
  return updated;
}

function triggerOnValue(updated) {
  var len = updated.length;
  for (var i = 0; i < len; i++) {
    var updatedSignal = updated[i];
    var value = updatedSignal.v;
    var callbacks = updatedSignal.callbacks;
    var callbacksLen = callbacks.length;
    for (var j = 0; j < callbacksLen; j++) {
      callbacks[j](value);
    }
  }
}

Transaction.prototype.commit = function () {

  // clear timeout
  if (this.commitScheduled) {
    clearTimeout(this.commitScheduled);
    this.commitScheduled = false;
  }

  // If nothing to do, short circuit
  if (this.actions.length === 0) {
    return;
  }

  // Data flow

  // traverse actions to aquire new values
  var updates = calculateUpdates(this.actions);

  // Apply updates, and collect updated signals
  var updated = initialSet(updates);

  // seed propagation push-pull propagation with children of updated sources
  var signals = {};
  updated.forEach(function (update) {
    update.children.forEach(function (child) {
      signals[child.index] = child;
    });
  });

  // until there aren't any signals
  while (!util.objIsEmpty(signals)) {
    // minimum rank
    var rank = Infinity;
    for (var rankK in signals) {
      rank = Math.min(rank, signals[rankK].rank);
    }

    var next = [];
    var curr = [];

    for (var k in signals) {
      var signal = signals[k];
      // skip signals of different (larger!) rank
      if (signal.rank !== rank) {
        continue;
      }

      // new value
      var value = signal.calculate();

      // if value is changed
      if (!signal.eq(signal.v, value)) {
        // set the value
        signal.v = value;

        // add signal to updated list
        updated.push(signal);

        // add children of updated signal to list of traversable signals
        var childrenlen = signal.children.length;
        for (var childIdx = 0; childIdx < childrenlen; childIdx++) {
          var child = signal.children[childIdx];
          next.push(child);
        }
      }

      // we are done with this signal
      curr.push(signal.index);
    }

    // Remove traversed
    var currLen = curr.length;
    for (var currIdx = 0; currIdx < currLen; currIdx++) {
      delete signals[curr[currIdx]];
    }

    // add next
    var nextLen = next.length;
    for (var nextIdx = 0; nextIdx < nextLen; nextIdx++) {
      signals[next[nextIdx].index] = next[nextIdx];
    }
  }

  // Trigger onValue callbacks
  triggerOnValue(updated);

  // rest cleanupg
  this.actions = [];
};

/**
  #### transaction.rollback

  Rollback the transaction. Maybe be called multiple times (consecutives calls are no-op).

  *Note: for now `rollback` only resets the pending actions in transactions. Transaction is still valid, and more actions can be added*
*/
Transaction.prototype.rollback = function() {
  if (this.commitScheduled) {
    clearTimeout(this.commitScheduled);
  }
  this.actions = [];
  this.commitScheduled = false;
};

Transaction.prototype.deferCommit = function () {
  if (!this.commitScheduled) {
    var tx = this;
    this.commitScheduled = setTimeout(function () {
      tx.commit();
    });
  }
};

Transaction.prototype.addAction = function (action) {
  this.actions.push(action);
  this.deferCommit();
};

Transaction.prototype.set = function (source, value) {
  source.set(this, value);
  return this;
};

Transaction.prototype.modify = function (source, f) {
  source.modify(this, f);
  return this;
};

module.exports = transaction;

},{"./util.js":8}],8:[function(require,module,exports){
/*
 * menrva
 * https://github.com/phadej/menrva
 *
 * Copyright (c) 2014 Oleg Grenrus
 * Licensed under the MIT license.
 */

"use strict";

function identity(x) {
  return x;
}

function pluck(arr, property) {
  var len = arr.length;
  var res = new Array(len);
  for (var i = 0; i < len; i++) {
    res[i] = arr[i][property];
  }
  return res;
}

function values(obj) {
  var arr = [];
  for (var k in obj) {
    arr.push(obj[k]);
  }
  return arr;
}

function objIsEmpty(obj) {
  /* jshint unused:false */
  for (var k in obj) {
    return false;
  }
  return true;
}

function getPath(obj, path) {
  var len = path.length;
  for (var i = 0; i < len; i++) {
    if (obj === undefined || obj === null) {
      return obj;
    } else {
      obj = obj[path[i]];
    }
  }
  return obj;
}

function setProperty(obj, property, value) {
  var copy = {};
  for (var k in obj) {
    copy[k] = obj[k];
  }
  copy[property] = value;
  return copy;
}

function setPath(obj, path, value) {
  var len = path.length;
  var acc = value;
  for (var i = len; i > 0; i--) {
    var next = getPath(obj, path.slice(0, i - 1));
    acc = setProperty(next, path[i - 1], acc);
  }
  return acc;
}

function modifyPath(obj, path, f) {
  return setPath(obj, path, f(getPath(obj, path)));
}

module.exports = {
  identity: identity,
  pluck: pluck,
  values: values,
  objIsEmpty: objIsEmpty,
  getPath: getPath,
  setPath: setPath,
  modifyPath: modifyPath,
};

},{}]},{},[4])(4)
});