import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { verifyPrimaryTabs } from './verify-android-product-navigation.mjs';

const nav = readFileSync(new URL(
  '../android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt',
  import.meta.url,
), 'utf8');

test('approved five-tab navigation passes against the Kotlin source', () => {
  assert.doesNotThrow(() => verifyPrimaryTabs(nav));
});

test('a route swap fails even when all five labels remain present', () => {
  const swapped = nav.replace(
    'Routes.CHAT, Routes.COMMUNITY, Routes.CREATE',
    'Routes.COMMUNITY, Routes.CHAT, Routes.CREATE',
  );
  assert.notEqual(swapped, nav);
  assert.throws(() => verifyPrimaryTabs(swapped), /expected HOME → DISCOVER → CHAT → COMMUNITY → CREATE/);
});

test('a sixth Profile tab fails', () => {
  const expanded = nav.replace(
    'Routes.CHAT, Routes.COMMUNITY, Routes.CREATE,',
    'Routes.CHAT, Routes.COMMUNITY, Routes.CREATE, Routes.PROFILE,',
  );
  assert.notEqual(expanded, nav);
  assert.throws(() => verifyPrimaryTabs(expanded), /expected HOME → DISCOVER → CHAT → COMMUNITY → CREATE/);
});

test('mapping Lyo to the wrong route or label fails', () => {
  const wrongLabel = nav.replace(
    'Routes.CHAT -> BottomItem(route, "Lyo", Icons.Filled.SmartToy)',
    'Routes.CHAT -> BottomItem(route, "Tutor", Icons.Filled.SmartToy)',
  );
  assert.notEqual(wrongLabel, nav);
  assert.throws(() => verifyPrimaryTabs(wrongLabel), /missing CHAT \/ Lyo \/ SmartToy mapping/);
});

test('the plus-tab-only visual contract cannot be removed silently', () => {
  const labeledPlus = nav.replace(
    'label = if (item.route == Routes.CREATE) null else ({ Text(item.label) })',
    'label = { Text(item.label) }',
  );
  assert.notEqual(labeledPlus, nav);
  assert.throws(() => verifyPrimaryTabs(labeledPlus), /Android unlabeled \+ icon/);
});
