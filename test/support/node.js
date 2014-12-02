"use strict";

var chai = require("chai");
var chaiAsPromised = require('chai-as-promised');

if (!Promise)
  var Promise = require('es6-promise').Promise;

// var Q = require("q");

chai.should();
chai.use(chaiAsPromised);

global.chaiAsPromised = chaiAsPromised;
global.expect = chai.expect;
global.AssertionError = chai.AssertionError;
global.Assertion = chai.Assertion;
global.assert = chai.assert;

global.fulfilledPromise = Promise.resolve;
global.rejectedPromise = Promise.reject;
// global.defer = Q.defer;
