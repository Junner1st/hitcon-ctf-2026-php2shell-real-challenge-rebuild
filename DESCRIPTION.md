- name: php2shell (real)
- description:

⚠️ Security & Privacy Notice

Please be aware that your payloads may be visible to the organizers. Also, consider the potential real-world security implications before publishing writeups or exploit details after the competition. We encourage responsible disclosure.

    There isn't an easy exploit for this php2shell vulnerability

yeah sure, but "not easy to exploit" != "not exploitable irl"
let’s see how true that is in the real world with this challenge

you get THREE instances:

    Nginx + PHP FPM + WordPress (x 2)
    Apache + WordPress (x 1)
    every instance runs randomized (vulnerable) PHP / WordPress versions, is already warmed up, and keeps getting random traffic.

so yeah, not your usual clean little lab env.
you need to pwn all three, and you only get 10 instance spawns total.

because let’s be real: irl the blue team probably noticed you after attempt #1 already 💀
