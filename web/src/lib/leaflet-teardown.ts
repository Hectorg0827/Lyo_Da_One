import type { Map as LeafletMap } from 'leaflet';

type AnimatingMap = LeafletMap & {
  _animatingZoom?: boolean;
  _onZoomTransitionEnd?: () => void;
};

/** Long enough for Leaflet's queued frame plus its 250 ms zoom-end timer. */
const SETTLE_MS = 400;

/**
 * Give each Leaflet map its own element inside the React-owned container.
 * A map being torn down keeps its (now detached) element until it settles,
 * so an immediate remount — a fast route change, or React's development
 * double-mount — never finds a container that is still "in use".
 */
export function createMapHost(container: HTMLElement): HTMLDivElement {
  const host = document.createElement('div');
  host.style.width = '100%';
  host.style.height = '100%';
  container.appendChild(host);
  return host;
}

/**
 * Remove a Leaflet map safely, even mid-animation.
 *
 * `fitBounds`/`setView` start zoom animations on the *next* animation frame
 * and finish them with a 250 ms timer. If the map is removed in between (the
 * learner taps "View details" while the map is still zooming), those
 * callbacks read the removed map pane and throw "Cannot read properties of
 * undefined (reading '_leaflet_pos')". So: stop listening now, let anything
 * already queued run against the still-intact (detached) map, then remove it.
 */
export function teardownMap(map: LeafletMap | null | undefined, host?: HTMLElement | null) {
  if (!map) return;
  try {
    map.stop();
    map.off();
  } catch {
    // Already partially torn down.
  }
  host?.remove();
  window.setTimeout(() => {
    try {
      const animating = map as AnimatingMap;
      if (animating._animatingZoom) animating._onZoomTransitionEnd?.();
      map.remove();
    } catch (error) {
      console.warn('Map teardown skipped', error);
    }
  }, SETTLE_MS);
}
