# Public-source research notes (2026-10-27)

## What could be verified about the HITCON challenge

- The supplied description says each spawn contains two Nginx/PHP-FPM/
  WordPress instances and one Apache/WordPress instance, with randomized
  vulnerable PHP and WordPress versions, prior warm-up, random traffic, three
  targets per spawn and ten total spawns.
- The public HITCON scoreboard showed `php2shell (real)` as a 500-point web
  challenge with zero solves on the indexed team page.
- Exact-name searches found no public writeup, attachment, organizer source, or
  solver discussion. Because there were no public solves and the event had only
  just ended, general PHP2Shell research is the main available evidence.
- Player observations supplied during this reconstruction confirm that the pool
  included PHP 5.6, 7.1, 7.4, 8.1, 8.4 and 8.5. The detailed handoff adds exact
  live observations for several Apache and FPM slots, but does not recover the
  organizer's complete randomizer or every PHP/WordPress pairing.

## Reproduction version profiles

`presets/versions/` contains a reproducible 2×2×2 matrix: PHP 5.6.35/5.6.39,
7.1.4/7.4.24 and 8.4.26/8.5.11. All except 5.6.39 are exact live or calibrated
lab versions named in the handoff. PHP 5.6.39 is retained as the second 5.6
choice from the earlier verified reconstruction because the handoff names only
one exact 5.6 patch release. The selected exact `php:<patch>` image is combined
with a fixed WordPress tarball at build time; these cross-product presets are
research cases, not claimed organizer spawn combinations.

## Technical consensus from the useful discussions

1. PHP maps CVE-2026-109618 to an OOM bailout that leaves request state in an
   invalid state before shutdown, and CVE-2026-109619 to request-owned global
   state surviving into a later request.
2. Apache mod_php is the clearest public RCE target because the interpreter and
   request lifecycle remain in a long-lived Apache child. PHP-FPM commonly
   kills and respawns the worker on the startup OOM path, changing what survives
   and making a universal chain much less reliable.
3. Reliable exploitation is sensitive to PHP build, SAPI, allocator layout,
   ASLR, worker selection, memory limit, request buffering and background
   traffic. A clean single-worker, 8 MiB lab does not model this challenge.
4. Public research demonstrates FPM session residue on vulnerable 8.4.26 and
   its absence on patched 8.4.27, while public mod_php research reports a full
   chain. This supports the challenge's deliberate mix of two FPM targets and
   one Apache target.
5. Many early repositories claimed universal RCE without an address leak,
   pinned build, matched patched control, or complete evidence. Treat claimed
   PoCs as build-specific until independently reproduced.

## Sources

- [Official PHP advisory: CVE-2026-109618 / OOM corruption](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)
- [Official PHP advisory: CVE-2026-109619 / stale global state](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)
- [PHP 2026 release archive](https://www.php.net/archive/2026.php)
- [HITCON CTF 2026 event page](https://www.hitcon.org/2026/CyberRangexCTF/ctf-en.html)
- [Indexed HITCON scoreboard page showing zero solves](https://ctf2026.hitcon.org/team/165)
- [Independent public-PoC evidence audit](https://github.com/sdminev/php2shell-poc)
- [SAPI differential lab and FPM residue results](https://github.com/RuxaXa/php2shell-sapi-differential)
- [SANS discussion of real-world reliability and memory limits](https://isc.sans.edu/diary/Reliable%2Bphp2shell%2Bexploitability/33452)

The two GitHub research repositories are independent secondary evidence, not
organizer material. Their claims are useful for lab design but should not be
confused with the official advisories or with a HITCON solution.
