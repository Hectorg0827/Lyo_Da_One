/**
 * Extract destinations that are actually registered as *direct* children of
 * the Android NavHost. A global source.includes("composable(Routes.CHAT)")
 * mistakenly approves dead code and routes hidden inside if(false) branches.
 *
 * This is a scoped static CI contract, not a replacement for device tests.
 */
function maskKotlin(source) {
  const hide = (part) => part.replace(/[^\n]/g, ' ');
  return source
    .replace(/"""[\s\S]*?"""/g, hide)
    .replace(/"(?:\\.|[^"\\])*"/g, hide)
    .replace(/\/\*[\s\S]*?\*\//g, hide)
    .replace(/\/\/[^\n]*/g, hide);
}

function matchingDelimiter(source, openingIndex, open, close) {
  let depth = 0;
  for (let i = openingIndex; i < source.length; i += 1) {
    if (source[i] === open) depth += 1;
    else if (source[i] === close) {
      depth -= 1;
      if (depth === 0) return i;
    }
  }
  throw new Error('Android NavHost: unbalanced ' + open + close + ' delimiters');
}

export function directNavHostRoutes(source) {
  const masked = maskKotlin(source);
  for (const call of masked.matchAll(/\bNavHost\s*\(/g)) {
    const open = masked.indexOf('(', call.index);
    const close = matchingDelimiter(masked, open, '(', ')');
    if (!/\bnavController\s*=\s*nav\b/.test(masked.slice(open + 1, close))) continue;

    const afterCall = masked.slice(close + 1).search(/\S/);
    const firstBrace = afterCall < 0 ? -1 : close + 1 + afterCall;
    if (firstBrace < 0 || masked[firstBrace] !== '{') {
      throw new Error('Android NavHost: missing destination registration lambda');
    }
    const endBrace = matchingDelimiter(masked, firstBrace, '{', '}');
    const bodyMask = masked.slice(firstBrace + 1, endBrace);
    const declarations = [...bodyMask.matchAll(/\bcomposable\s*\(\s*Routes\.([A-Z_]+)\b/g)]
      .map((match) => ({offset: firstBrace + 1 + match.index, route: match[1]}));

    const routes = [];
    let depth = 1;
    let next = 0;
    for (let i = firstBrace + 1; i < endBrace; i += 1) {
      if (i === declarations[next]?.offset) {
        if (depth === 1) routes.push(declarations[next].route);
        next += 1;
      }
      if (masked[i] === '{') depth += 1;
      else if (masked[i] === '}') depth -= 1;
    }
    return {routes, body: source.slice(firstBrace + 1, endBrace)};
  }
  throw new Error('Android NavHost with navController = nav was not found');
}

export function requireExactlyOneDirectRoute(source, route) {
  const registered = directNavHostRoutes(source).routes;
  const count = registered.filter((name) => name === route).length;
  if (count !== 1) {
    throw new Error('Android NavHost: ' + route + ' must be registered exactly once at top level (found ' + count + ')');
  }
}
