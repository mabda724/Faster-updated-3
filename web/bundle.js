var PasskeyAuthenticator = {};
PasskeyAuthenticator.init = function() {};
PasskeyAuthenticator.register = function(params) {
  return Promise.reject('{"code":"not-supported","message":"Passkeys not available.","details":""}');
};
PasskeyAuthenticator.login = function(params) {
  return Promise.reject('{"code":"not-supported","message":"Passkeys not available.","details":""}');
};
PasskeyAuthenticator.cancelCurrentAuthenticatorOperation = function() {};
PasskeyAuthenticator.isUserVerifyingPlatformAuthenticatorAvailable = function() {
  return Promise.resolve(false);
};
PasskeyAuthenticator.isConditionalMediationAvailable = function() {
  return Promise.resolve(false);
};
PasskeyAuthenticator.hasPasskeySupport = function() { return false; };
