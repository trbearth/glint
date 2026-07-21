ObjC.import('Foundation');

function readJSON(path) {
  var text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null).js;
  return JSON.parse(text || '{}');
}

function writeJSON(path, value) {
  var text = JSON.stringify(value, null, 2) + '\n';
  $(text).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}

function hasCommand(entries, command) {
  return (entries || []).some(function (entry) {
    return (entry.hooks || []).some(function (hook) { return hook.command === command; });
  });
}

function removeCommand(entries, command) {
  return (entries || []).map(function (entry) {
    var copy = Object.assign({}, entry);
    copy.hooks = (entry.hooks || []).filter(function (hook) { return hook.command !== command; });
    return copy;
  }).filter(function (entry) { return entry.hooks.length > 0; });
}

function removeGlintCommands(entries) {
  return (entries || []).map(function (entry) {
    var copy = Object.assign({}, entry);
    copy.hooks = (entry.hooks || []).filter(function (hook) {
      return !hook.command || hook.command.indexOf('/Glint.app/Contents/MacOS/glint') === -1;
    });
    return copy;
  }).filter(function (entry) { return entry.hooks.length > 0; });
}

function run(argv) {
  var mode = argv[0], path = argv[1], first = argv[2], second = argv[3];
  var value = readJSON(path); value.hooks = value.hooks || {};
  if (mode === 'add-codex') {
    value.hooks.UserPromptSubmit = removeGlintCommands(value.hooks.UserPromptSubmit);
    if (!hasCommand(value.hooks.UserPromptSubmit, first))
      value.hooks.UserPromptSubmit.push({hooks: [{type: 'command', command: first, timeout: 5}]});
  } else if (mode === 'add-claude') {
    value.hooks.Stop = removeGlintCommands(value.hooks.Stop);
    value.hooks.UserPromptSubmit = removeGlintCommands(value.hooks.UserPromptSubmit);
    if (!hasCommand(value.hooks.Stop, first))
      value.hooks.Stop.push({matcher: '*', hooks: [{type: 'command', command: first}]});
    if (!hasCommand(value.hooks.UserPromptSubmit, second))
      value.hooks.UserPromptSubmit.push({hooks: [{type: 'command', command: second}]});
  } else if (mode === 'remove-codex') {
    value.hooks.UserPromptSubmit = removeGlintCommands(value.hooks.UserPromptSubmit);
  } else if (mode === 'remove-claude') {
    value.hooks.Stop = removeGlintCommands(value.hooks.Stop);
    value.hooks.UserPromptSubmit = removeGlintCommands(value.hooks.UserPromptSubmit);
  }
  writeJSON(path, value);
}
