import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const repo = (path) => readFileSync(new URL('../../../' + path, import.meta.url));
const source = (path) => repo(path).toString('utf8');

test('iOS, Android and mobile web use the exact same canonical Lyo artwork', () => {
  const canonical = repo('Sources/Resources/Assets.xcassets/LyoAvatar.imageset/lyo-avatar.png');
  assert.deepEqual(repo('web/public/mascot/lyo_live_front.png'), canonical);
  assert.deepEqual(repo('android/app/src/main/res/drawable-nodpi/lyo_live_front.png'), canonical);
  assert.match(source('Sources/Views/Chat/VoiceSessionBottomSheet.swift'), /Image\("LyoAvatar"\)/);
  assert.match(source('android/app/src/main/java/com/lyo/app/ui/screens/chat/MagicalLyoLiveScreen.kt'), /R\.drawable\.lyo_live_front/);
  assert.match(source('web/src/components/chat/MascotAvatar.tsx'), /liveHero[\s\S]*lyo_live_front\.png/);
});

test('iOS Live is immersive and returns to its existing Chat conversation', () => {
  const overlay = source('Sources/Views/Main/Hybrid/LyoOverlayView.swift');
  const live = source('Sources/Views/Chat/VoiceSessionBottomSheet.swift');
  const vm = source('Sources/ViewModels/LyoAIViewModel.swift');
  assert.match(overlay, /\.fullScreenCover\(isPresented: \$showVoiceSheet/);
  assert.match(overlay, /conversationManager\.createNewConversation\(\)/);
  assert.match(overlay, /VoiceSessionBottomSheet\(viewModel: viewModel, onExit:/);
  assert.match(live, /viewModel\.stopLiveMode\(\)/);
  assert.match(live, /viewModel\.sendMessage\(mode: "Chat"\)/);
  assert.match(live, /PhotosPicker\(selection: \$photoItems/);
  assert.match(live, /processDocumentURL\(url\)/);
  assert.match(vm, /func pauseLiveMicrophone\(\)/);
  assert.match(vm, /func resumeLiveMicrophone\(\)/);
  assert.doesNotMatch(live, /CallEnd|phone\.down\.fill/);
});

test('mobile web Live has one inline mic, safe-area keyboard viewport and one canonical Chat store', () => {
  const web = source('web/src/components/chat/ConversationalVoiceLayer.tsx');
  const css = source('web/src/components/chat/lyo-live-magic.css');
  const store = source('web/src/stores/chat-store.ts');
  assert.match(web, /ref=\{liveViewportRef\}/);
  assert.match(web, /toggleLiveMicrophone/);
  assert.match(web, /micPausedRef\.current/);
  assert.match(web, /setVoiceSessionActive\(false\)/);
  assert.match(css, /--lyo-live-visual-height/);
  assert.match(css, /safe-area-inset-bottom/);
  assert.match(css, /lyo-live-magic__control-stack/);
  assert.match(store, /createConversation\(\)/);
  assert.doesNotMatch(web, /className="lyo-live-magic__hangup"/);
});
