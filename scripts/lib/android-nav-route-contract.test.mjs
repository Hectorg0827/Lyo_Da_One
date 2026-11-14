import test from 'node:test';
import assert from 'node:assert/strict';
import {directNavHostRoutes, requireExactlyOneDirectRoute} from './android-nav-route-contract.mjs';

const valid = [
  'val fakeRoute = "composable(Routes.NOT_A_ROUTE) { }"',
  '// composable(Routes.MORE_FAKE) { }',
  'NavHost(',
  '  navController = nav,',
  '  startDestination = if (Session.isAuthenticated) Routes.HOME else Routes.LOGIN,',
  '  modifier = Modifier.padding(padding),',
  ') {',
  '  composable(Routes.HOME) { HomeScreen(nav) }',
  '  composable(Routes.DISCOVER) { ClipsScreen(nav) }',
  '  composable(Routes.CHAT) { ChatScreen(nav, chatSession) }',
  '  composable(Routes.COMMUNITY) { CommunityScreen(nav) }',
  '  composable(Routes.CREATE) { CreateScreen(nav) }',
  '  composable(Routes.COURSE_DETAIL) { entry -> Text("{braces within quotes}") }',
  '}',
].join('\n');

test('only direct destinations in the real NavHost are registered', () => {
  const {routes, body} = directNavHostRoutes(valid);
  assert.deepEqual(routes, ['HOME', 'DISCOVER', 'CHAT', 'COMMUNITY', 'CREATE', 'COURSE_DETAIL']);
  assert.match(body, /ChatScreen\(nav, chatSession\)/);
  requireExactlyOneDirectRoute(valid, 'CHAT');
});

test('hidden or unreachable Chat route cannot masquerade as registered', () => {
  const hidden = valid.replace(
    '  composable(Routes.CHAT) { ChatScreen(nav, chatSession) }',
    '  if (false) { composable(Routes.CHAT) { ChatScreen(nav, chatSession) } }',
  );
  assert.throws(() => requireExactlyOneDirectRoute(hidden, 'CHAT'), /found 0/);
});

test('duplicate Chat route is rejected', () => {
  const duplicate = valid.replace(
    '  composable(Routes.CHAT) { ChatScreen(nav, chatSession) }',
    '  composable(Routes.CHAT) { ChatScreen(nav, chatSession) }\n  composable(Routes.CHAT) { ChatScreen(nav, chatSession) }',
  );
  assert.throws(() => requireExactlyOneDirectRoute(duplicate, 'CHAT'), /found 2/);
});

test('commented routes and route strings are ignored', () => {
  const source = valid + '\n// composable(Routes.EXTRA) { }\nval label = "composable(Routes.EXTRA)"\n';
  assert.ok(!directNavHostRoutes(source).routes.includes('EXTRA'));
});

test('missing NavHost fails closed', () => {
  assert.throws(() => directNavHostRoutes('composable(Routes.CHAT) { ChatScreen(nav) }'), /not found/);
});
