/**
 * The one long-form document the Article screen ships with.
 *
 * Everything except `body` is masthead furniture drawn in React Native;
 * `body` is the markdown the library renders — prose, LaTeX, two native
 * video players, a table and a code block, from a single string.
 */
export type Article = {
  kicker: string;
  title: string;
  deck: string;
  authorName: string;
  authorInitials: string;
  publishedOn: string;
  readingTime: string;
  body: string;
};

// Both clips are from NASA Goddard's "Black Hole Accretion Disk Visualization"
// (SVS 13326, Jeremy Schnittman, 2019). Public domain, 1920×1080.
const HERO_VIDEO =
  'https://svs.gsfc.nasa.gov/vis/a010000/a013300/a013326/BH_AccretionDisk_Sim_Stationary_1080.mp4';
const ORBIT_VIDEO =
  'https://svs.gsfc.nasa.gov/vis/a010000/a013300/a013326/BH_AccretionDisk_Sim_360_Center_16x9_1080.mp4';

// String.raw keeps LaTeX backslashes intact. Code fences use `~~~` so no
// backticks need escaping inside the template.
const body = String.raw`
<video src="${HERO_VIDEO}"></video>

###### Fig. 1 · A thin accretion disk around a non-rotating black hole, seen from just above its plane. NASA Goddard / J. Schnittman.

> **Abstract.** A black hole emits nothing, yet the one in NASA's simulation is the brightest thing on the screen. Everything visible is the disk of gas around it, and everything strange about the picture — the halo over the top, the lopsided glow — is the geometry of spacetime acting on light that was already on its way to the camera.

## Nothing comes back

Take a mass $M$ and squeeze it. There is a radius below which the escape velocity reaches $c$, and Schwarzschild found it in 1916 by solving Einstein's equations for the empty space around a point mass:

$$r_s = \frac{2GM}{c^2}$$

For the Sun that is $2.95\ \mathrm{km}$; for the Earth, nine millimetres. The full solution is the metric,

$$ds^2 = -\left(1 - \frac{r_s}{r}\right) c^2\, dt^2 + \left(1 - \frac{r_s}{r}\right)^{-1} dr^2 + r^2\, d\Omega^2$$

and every feature in the video is a consequence of the factor $\left(1 - r_s/r\right)$ going to zero at the horizon.

## Where light orbits

Light is bent by gravity, and close enough to the hole the bending closes on itself. At the photon sphere,

$$r_{\mathrm{ph}} = \frac{3}{2}\, r_s = \frac{3GM}{c^2}$$

a photon aimed just right circles the hole forever. Anything aimed slightly inward is captured, which is why the dark region in the middle — the shadow — is larger than the horizon:

$$b_{\mathrm{c}} = 3\sqrt{3}\, \frac{GM}{c^2} \approx 2.6\, r_s$$

The photon ring sits at the edge of that shadow. Farther out, a ray passing at impact parameter $b$ is deflected by

$$\delta \approx \frac{4GM}{c^2 b}$$

which is small at a distance and enormous near the ring. The far side of the disk is behind the hole, and you can still see it — its light is bent up over the top and down under the bottom, so the back of the disk appears as a halo above and below the front.

<video src="${ORBIT_VIDEO}"></video>

###### Fig. 2 · The same disk as the camera circles it. Edge-on, the halo folds into the front of the disk; face-on, it disappears.

## Why one side is brighter

The disk rotates at a good fraction of $c$. Gas coming toward the camera is Doppler-boosted, gas moving away is dimmed, and the boost goes as the cube of the Doppler factor:

$$I_{\mathrm{obs}} = \delta^{3}\, I_{\mathrm{emit}}, \qquad \delta = \frac{1}{\gamma\left(1 - \beta\cos\theta\right)}$$

Stacked on top is the gravitational redshift. A photon climbing out from radius $r$ arrives with

$$\frac{\nu_\infty}{\nu_r} = \sqrt{1 - \frac{r_s}{r}}$$

so ==the inner edge is both the hottest and the most reddened== part of the disk. In the video the left side is brighter than the right; that is the direction of rotation, read straight off the image.

- **Event horizon** — $r = r_s$, the surface nothing crosses outward
- **Photon sphere** — $r = 1.5\, r_s$, where light can orbit
- **Innermost stable orbit** — $r = 3\, r_s$, the inner edge of the disk

> The hole itself is not in the picture. What you are looking at is a map of where light can and cannot go, drawn by gas that happened to be passing through.

### The last stable orbit

Circular orbits exist all the way down to the photon sphere, but below $r_{\mathrm{ISCO}} = 3\, r_s$ they are unstable: a nudge inward and the gas spirals in within a few turns. That is why the disk has a sharp inner edge, and why matter crossing it gives up so much of its rest energy — for a non-rotating hole,

$$\eta = 1 - \sqrt{\frac{8}{9}} \approx 5.7\%$$

which is roughly ten times what fusion manages.

## Three black holes

| Object | Mass | $r_s$ |
| --- | --- | --- |
| Cygnus X-1 | $21\, M_\odot$ | $62\ \mathrm{km}$ |
| Sagittarius A\* | $4.3 \times 10^{6}\, M_\odot$ | $0.08\ \mathrm{au}$ |
| M87\* | $6.5 \times 10^{9}\, M_\odot$ | $130\ \mathrm{au}$ |

Sagittarius A\* and M87\* are the two whose shadows the Event Horizon Telescope has imaged. Their apparent sizes on the sky are nearly equal: M87\* is fifteen hundred times heavier, and about two thousand times farther away.

## Tracing a ray

Numerically the picture is a loop over pixels. With $u = 1/r$, a light ray around a Schwarzschild mass obeys

$$\frac{d^2 u}{d\phi^2} + u = \frac{3}{2}\, r_s\, u^2$$

a harmonic oscillator with one nonlinear term. Step it and stop when the ray either falls in or escapes, returning the deflection angle:

~~~ts
const step = 1e-3;

function trace(b: number, rs: number) {
  let u = 1e-6; // u = 1 / r, far away
  let du = 1 / b; // set by impact b
  let phi = 0;

  while (phi < 4 * Math.PI) {
    du += (1.5 * rs * u * u - u) * step;
    u += du * step;
    phi += step;
    if (u > 1 / rs) return 'captured';
    if (u <= 0) return phi - Math.PI;
  }
  return 'orbiting';
}
~~~

Rays with $b$ below the critical value fall in and paint the shadow. Rays just above it loop once or twice around the photon sphere before leaving — those are the ones that draw the thin bright ring.

---

*Simulation: [Black Hole Accretion Disk Visualization](https://svs.gsfc.nasa.gov/13326), NASA Goddard Space Flight Center / Jeremy Schnittman (2019). Further reading: [Schwarzschild, 1916](https://en.wikipedia.org/wiki/Schwarzschild_metric) and the [Event Horizon Telescope](https://eventhorizontelescope.org/).*
`.trim();

export const featuredArticle: Article = {
  kicker: 'General Relativity',
  title: 'The Shape of a Shadow',
  deck: 'What an accretion disk looks like from outside, and why you can see its far side from the front.',
  authorName: 'Ada Lindqvist',
  authorInitials: 'AL',
  publishedOn: 'September 2026',
  readingTime: '7 min read',
  body,
};
