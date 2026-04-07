# NixOS Setup Video Script V2

This is the tone-adjusted version.
Same structure as the first script, but written to feel closer to your own voice: more personal, less formal, and less "AI presenter".

## Video 1: One Flake, Three Machines

### Scene 1 - 0:00 to 0:35

Voiceover

"Hey everyone, sorry it has been a while again. Hope you are all doing good.

Today I want to show you how Nix kind of took over all the devices I am using right now. This is not a tutorial, and I am definitely not presenting this as some perfect setup. If anything, I would say be a bit critical of everything I did here, because a lot of this only exists because I kept running into little problems and ended up solving them in code.

Right now I regularly use three computers. My work laptop, which is a Surface Studio, and NixOS honestly improved that machine quite a lot. Then there is my Lenovo T14 Gen 5, which was in my more recent video. And then there is my desktop PC that I built myself. If you want to see more of that machine, there is a video on my Star Citizen channel, I will link it below.

So yeah, that is the setup I want to walk through."

Remotion

Three machine cards slide in one after another:

1. `work`
2. `l`
3. `pc`

Then they all collapse into one `flake.nix` card.

Screen recording

None at the start.

Real-life recording

Quick montage:

1. work laptop on the dock
2. Lenovo laptop opening
3. desktop setup powering on

### Scene 2 - 0:35 to 1:15

Voiceover

"At the top of everything is `flake.nix`. That is the entry point for the whole setup.

Instead of having three separate configs that all just kind of exist on their own, I have one flake that exports three machines. And that gives the whole repo a pretty clear shape immediately. Once you see that file, you already understand the basic idea."

Remotion

Simple graph:

`flake.nix`
-> `pc`
-> `l`
-> `work`

Then each branch splits into:

1. `hosts`
2. `home`

Screen recording

Open the repo root, then `flake.nix`. Highlight the `nixosConfigurations` block.

Real-life recording

None.

### Scene 3 - 1:15 to 2:00

Voiceover

"One thing I really like in here is that I only define the host-building pattern once.

There is this `mkHost` function, and it takes the host name, the Home Manager host file, and the username. From that it builds the full machine. I like that because it keeps the flake much tidier, and it also means the system layer and the user layer are already connected from the start instead of being two separate things I have to mentally stitch together later."

Remotion

Builder animation:

1. `hostName`
2. `homeHost`
3. `hmUser`

go into one `mkHost` block and come out as a complete machine card.

Screen recording

Code close-up on `mkHost` in `flake.nix`. Scroll just enough to show the Home Manager injection.

Real-life recording

None.

### Scene 4 - 2:00 to 2:50

Voiceover

"Compared to the flake, the host files themselves are actually pretty small.

And I really prefer it that way, because they mostly just describe what each machine is made of. The desktop pulls in the heavier stuff, the laptop stays simpler, and the work machine brings in all the extra pieces it needs to deal with its own hardware and all the work-related weirdness around it.

That is basically the whole idea. The flake sets the pattern, and the host files describe the machine."

Remotion

Three-column host comparison.
Shared imports appear first.
Host-specific imports appear second in a brighter accent color.

Screen recording

Open:

1. `hosts/pc/default.nix`
2. `hosts/l/default.nix`
3. `hosts/work/default.nix`

Keep the shots tight on the import lists.

Real-life recording

Very short cutaway to each machine after its host file is shown.

### Scene 5 - 2:50 to 3:55

Voiceover

"All three of those host files are built on top of the same shared `base.nix`.

This is where all the common stuff lives: networking, boot, Docker, libvirt, the display manager, `niri`, `fish`, fonts, portals, all of that. Then there is a separate optimization layer that handles updates, garbage collection, trim, store cleanup, and the more boring NixOS maintenance stuff.

That split is not especially fancy. It is mostly there because it makes the repo easier for me to navigate. I like keeping the base smaller and having the maintenance-related things in their own place."

Remotion

Stack animation:

1. shared base services
2. maintenance layer

with side cards for:

1. upgrades
2. garbage collection
3. trim
4. firmware

Screen recording

Open:

1. `hosts/common/base.nix`
2. `hosts/common/optimisations.nix`

Highlight the main service sections.

Real-life recording

None.

### Scene 6 - 3:55 to 5:00

Voiceover

"Now if we leave the `hosts` folder and go to the other side of the repo, it is really the same general idea again.

Each machine gets a Home Manager host file, and that pulls in the pieces that make the setup fit the actual day-to-day use of that machine. So there are apps, terminals, editors, browsers, audio stuff, shell stuff, and a few workflow scripts as well.

I am pretty fond of this split because it keeps the operating system side and the day-to-day side separate without making them feel disconnected."

Remotion

Graph shifts from:

`hosts/<machine>`

to:

`home/hosts/<machine>`

Then it fans out into module tiles:

1. `applications`
2. `kitty`
3. `nvfvim`
4. `niri`
5. `audio`
6. `buildandpush`

Screen recording

Open:

1. `home/hosts/pc.nix`
2. `home/hosts/work.nix`

Then jump into the module import lists.

Real-life recording

None.

### Scene 7 - 5:00 to 5:55

Voiceover

"And if you follow that all the way through to the actual running desktop, the stack is honestly pretty straightforward.

The machine boots a NixOS generation, SDDM starts the session, `niri` handles the windowing, and then Noctalia becomes the shell layer on top. So even though the repo is modular, it still maps pretty naturally to what the machine is actually doing once it is running.

I always like that. If the structure in the repo lines up with the structure of the real machine, it is just easier to reason about."

Remotion

Full stack animation:

1. NixOS generation
2. SDDM
3. `niri`
4. Noctalia
5. apps

Each layer lights up in sequence.

Screen recording

Quick login-to-desktop capture ending on the finished session.

Real-life recording

Short camera shot of the monitor waking up and reaching the desktop.

### Scene 8 - 5:55 to 6:35

Voiceover

"So that is basically the rough shape of the repo.

It is not some perfect architecture blueprint. It just makes sense to me. Shared things go in shared modules, machine-specific pain goes in feature modules, and the actual daily experience lives in Home Manager.

That is kind of the lens for the rest of the video as well, because from here on out I want to get more into the part you actually notice when you sit down and use the machine."

Remotion

Summary card with three labels:

1. shared stuff
2. machine-specific pain
3. daily experience

Screen recording

Slow zoom over the repo tree one last time.

Real-life recording

None.

## Video 2: The Desktop Experience

### Scene 1 - 0:00 to 0:25

Voiceover

"Alright, so this is the part I actually spend time in every day.

And for me this is where the setup stops being a pile of config files and starts feeling like an environment. It is not just Wayland because Wayland is fashionable, or `niri` because I wanted something niche. It is more that once the session is running, all the little pieces start fitting together in a way I actually enjoy using."

Remotion

Minimal labels over live footage:

1. `niri`
2. Noctalia
3. `kitty`
4. `qutebrowser`
5. `nvf`

Screen recording

Cold open desktop capture:

1. launcher
2. terminal
3. browser
4. editor
5. settings

Real-life recording

Optional desk-side angle for the first few seconds.

### Scene 2 - 0:25 to 1:20

Voiceover

"One thing I like about the `niri` setup is that I did not start from zero.

I take the upstream default config and patch it instead. That feels much more natural to me than rewriting the whole thing from scratch, because I get to keep the parts that are already sensible and only change the bits that actually affect how I use the desktop."

Remotion

Before-and-after animation:

1. stock `niri` config
2. patched config

with replacements sliding across the screen.

Screen recording

Open `home/modules/niri/default.nix` and highlight the `replaceStrings` logic.

Real-life recording

None.

### Scene 3 - 1:20 to 2:20

Voiceover

"A lot of the feel comes from these smaller swaps.

Waybar goes away. The launcher gets routed through Noctalia. The lock flow gets replaced. Kitty becomes the terminal. A couple of bindings change so the whole thing feels a bit more coherent.

None of that is especially dramatic on its own. But together it changes the entire session. It stops feeling like a default compositor setup and starts feeling like something that is actually mine."

Remotion

Animated replacement list:

1. Waybar -> Noctalia
2. stock launcher -> Noctalia launcher
3. stock lock -> Noctalia lock
4. Alacritty -> Kitty

Screen recording

Real desktop keybind demo:

1. launcher
2. control center
3. settings
4. terminal
5. lock

Real-life recording

Close shot of keyboard for one or two keybinds only.

### Scene 4 - 2:20 to 3:25

Voiceover

"Noctalia is also one of the places where the three machines start to feel different.

The desktop gets the fuller version with more shell around it. The laptop keeps things a bit simpler. And the work setup strips some of that back, because on that machine reliability matters more than having every little visual thing turned on.

I like that a lot, because it means even the shell is adapting to the machine instead of pretending there is one ideal setup for every device."

Remotion

Three shell mockups side by side.
Desktop gets the richest one.
Laptop gets the middle version.
Work gets the stripped-back version.

Screen recording

Open `home/modules/niri/noctalia/default.nix`, then cut to live captures of the shell on each machine if possible.

Real-life recording

Short shot of:

1. desktop monitor setup
2. laptop
3. docked work setup

### Scene 5 - 3:25 to 4:15

Voiceover

"The same thing happens with the monitor layout.

The laptop just needs a clean internal display setup. The desktop is built around a wider main screen and a second display. And the work machine has a much more annoying monitor situation, so the config gets way more explicit there.

I think that is one of the better examples of the repo reflecting reality instead of trying to hide it. The machines are different, so the config is different."

Remotion

Animated monitor rectangles for:

1. laptop
2. desktop
3. work

Show:

1. scaling
2. portrait rotation
3. output labels where needed

Screen recording

Scroll through the output sections in the `niri` config, then show each machine's real arrangement.

Real-life recording

Camera pan across the actual monitor layouts.

### Scene 6 - 4:15 to 5:10

Voiceover

"Kitty is probably the clearest example of the setup having a specific mood.

The font is big, the colors are pushed pretty hard, and the whole thing feels deliberately styled rather than accidentally inherited from some default. It is not trying to be neutral. It is trying to feel like part of the same desktop as everything else."

Remotion

Terminal palette spread:

1. tabs
2. borders
3. cursor
4. URL styling
5. blur

Screen recording

Open Kitty, switch tabs, hover a URL, and show the font and theme clearly.
Brief code shot of `home/modules/kitty/default.nix`.

Real-life recording

None.

### Scene 7 - 5:10 to 6:05

Voiceover

"And that mood carries over into the other apps too.

`qutebrowser` gets custom styling. Kdenlive gets a matching colorscheme. So the general look spreads out beyond the terminal, which I always like. It makes the whole setup feel more like one environment instead of one themed app sitting in the middle of a bunch of unrelated defaults."

Remotion

Palette morph from terminal colors into browser and editor colors.

Screen recording

Show:

1. `qutebrowser`
2. a few pages
3. Kdenlive opening with the theme applied

Real-life recording

None.

### Scene 8 - 6:05 to 7:05

Voiceover

"Neovim follows the same pattern.

It is managed through NVF, so it is still declarative, but it does not feel sterile. Telescope, Gitsigns, toggleterm, lazygit, the dashboard, and the language support all come from the config, but the result still feels like a personal editor rather than just a generated one.

That is probably the line I care about the most with this setup in general. I want it to be declarative, but I do not want it to feel generic."

Remotion

Editor feature cards slide in one by one over a stylized code background.

Screen recording

Open Neovim and show:

1. dashboard
2. Telescope
3. Gitsigns
4. terminal split or lazygit

Real-life recording

None.

### Scene 9 - 7:05 to 7:55

Voiceover

"There are also a few creator-focused touches in here.

OBS is already part of the environment, EasyEffects has a voice preset, and the whole machine is very obviously set up with recording and editing in mind. That matters to me, because this is not just a machine I configure for fun. It is also a machine I use to make things."

Remotion

Subtle audio-reactive lower third with labels for:

1. OBS
2. EasyEffects
3. mic chain

Screen recording

Show:

1. OBS
2. EasyEffects preset
3. short mic level check

Real-life recording

Short shot of microphone or camera rig at the desk.

### Scene 10 - 7:55 to 8:30

Voiceover

"So yeah, the desktop side of the setup is basically `niri` for the windowing, Noctalia for the shell, and then a bunch of modules that slowly push everything toward the same overall feel.

It is probably not the cleanest or most minimal way to do it, but it feels good to use, and for me that matters a lot."

Remotion

Recap card:

1. windowing
2. shell
3. tools
4. style

Screen recording

Fast recap montage:

1. launcher
2. terminal
3. browser
4. editor
5. media tools

Real-life recording

None.

## Video 3: The Three Hosts And Why They Differ

### Scene 1 - 0:00 to 0:30

Voiceover

"If I just put the three hosts next to each other, the repo gets much easier to understand.

The desktop is the fullest version of the setup. The laptop is the simpler one. And the work machine is the one carrying the most compromise.

They all share the same foundation, but they very clearly do not have the same job, and I think that is why the host structure works."

Remotion

Three large host cards:

1. `pc`
2. `l`
3. `work`

with subtitles:

1. creator + gaming
2. portable daily driver
3. docked dev stack

Screen recording

Quick split-view of the three host files.

Real-life recording

Three quick physical shots:

1. desktop
2. laptop
3. docked work setup

### Scene 2 - 0:30 to 1:25

Voiceover

"The desktop is the most loaded one.

It gets AMD graphics, media tooling, extra storage, Flatpak, and the gaming module. This is basically the machine where I let the setup stretch out a bit and support more of the fun and messy stuff, not just the clean shared base system."

Remotion

Desktop host column expands.
Module badges stack around it:

1. AMD
2. media
3. gaming
4. mass storage
5. Flatpak

Screen recording

Open `hosts/pc/default.nix`, then jump into the imported feature modules.

Real-life recording

Camera shot of the main desktop setup.

### Scene 3 - 1:25 to 2:35

Voiceover

"The gaming module is probably the best example of the repo being personal rather than theoretical.

It is not trying to solve Linux gaming in some universal way. It is just me taking all the annoying little workarounds I needed for my own machine and pinning them down in code so I do not have to rediscover them later.

That is honestly one of my favorite things about using Nix on a personal machine. Little bits of weirdness stop being random notes in my head and start becoming part of the setup."

Remotion

Problem-to-fix sequence:

1. launcher weirdness
2. monitor issue
3. ultrawide detection
4. `USER.cfg` drift

Each resolves into a module block.

Screen recording

Open `hosts/features/gaming.nix` and highlight the launch flow.
If possible, include a short launcher or game-start clip.

Real-life recording

Wide camera shot of the desktop monitors during this segment.

### Scene 4 - 2:35 to 3:20

Voiceover

"Then the laptop is kind of the nice counterexample.

It stays pretty simple, and that is exactly why I like it. It inherits the same shared base, the same Home Manager ideas, and the same overall feel, but it only carries what it actually needs to be a clean portable machine.

Sometimes the best sign that a setup is structured well is that the simple machine still gets to stay simple."

Remotion

Laptop host card zooms forward while the others fade back.

Screen recording

Open `hosts/l/default.nix` and show how short it is.
Follow with a quick laptop desktop capture.

Real-life recording

Simple handheld shot of the laptop opening and waking up.

### Scene 5 - 3:20 to 4:20

Voiceover

"The work machine is really the opposite story.

It has a different user setup, a different hardware situation, more development tooling, and a docked display setup that is just more fragile. So this host carries a lot more exceptions, not because that is elegant, but because that is honestly what the machine needs."

Remotion

Work host card expands with tags:

1. user override
2. NVIDIA
3. DisplayLink
4. local certs
5. VirtualBox

Screen recording

Open `hosts/work/default.nix` and highlight:

1. user override
2. imports
3. forced video drivers

Real-life recording

Camera shot of dock, cables, and monitor setup.

### Scene 6 - 4:20 to 5:20

Voiceover

"Once you open the work-only modules, you can see that it is not just a desktop. It is also a local dev box.

Docker starts with the system, Java is there, Node is there, PHP is there, MariaDB is there, Caddy is there, and the local domains are wired in as well. So this machine is basically carrying a small work environment around with it."

Remotion

Service pipeline animation with cards for:

1. Docker
2. Java
3. Node
4. PHP
5. MariaDB
6. Caddy
7. local domains

Screen recording

Open:

1. `hosts/features/work/cx.nix`
2. `hosts/features/work/db.nix`
3. `hosts/features/work/caddy.nix`

Show the service sections, then a short terminal or browser demo if available.

Real-life recording

None.

### Scene 7 - 5:20 to 6:30

Voiceover

"And then there is DisplayLink, which is probably the clearest example of why I do not want to pretend this repo is best practice.

The work machine needs driver fixes, service fixes, a forced render path, and a lighter shell profile just to behave properly. But I would still much rather encode that mess than leave it as a bunch of half-remembered notes in my head.

That is basically the whole work-host philosophy right there. It is not pretty, but it is honest."

Remotion

Four-step problem-to-fix animation:

1. driver source
2. `evdi`
3. service ordering
4. forced Intel render node

Then show a simplified work-shell card.

Screen recording

Open:

1. `hosts/features/work/displaylink.nix`
2. work-specific branches in `niri`
3. work-specific branches in Noctalia

Real-life recording

Show the work setup driving the external monitors.

### Scene 8 - 6:30 to 7:10

Voiceover

"So I guess the quick version is:

The desktop gets the nice heavy version.
The laptop gets the simple version.
And the work machine gets the survival version.

It is not perfect, but it is honest, and I think that honesty is a big part of why the whole repo still makes sense to me."

Remotion

Final host comparison with all shared layers locking underneath the three different tops.

Screen recording

End on the `hosts/` directory and the three default files.

Real-life recording

Quick final montage of all three machines.

## Video 4: Rebuild Workflow, Maintenance, And Why It Holds Together

### Scene 1 - 0:00 to 0:25

Voiceover

"The last part I want to show is how I actually maintain all of this, because for me that is a big part of whether a setup is good or not.

It is one thing to make a nice config once. It is another thing to keep living with it without it turning into a mess."

Remotion

Typed command animation:

`buildall --sync-noctalia pc`

Each stage splits off to the side.

Screen recording

Terminal typing the command and pausing before execution.

Real-life recording

Optional side camera shot of hands at the keyboard.

### Scene 2 - 0:25 to 1:10

Voiceover

"I bundled a few commands into the setup for that:

`pushconfigs`, `flakeonly`, `syncnoctalia`, `buildall`, and `pushonly`.

None of these are especially glamorous, but together they cover the loop of updating the repo, rebuilding the machine, syncing shell changes, and pushing everything back up."

Remotion

Five command cards appear in sequence, then connect into one loop.

Screen recording

Open `home/modules/buildandpush/default.nix` and highlight the command definitions.

Real-life recording

None.

### Scene 3 - 1:10 to 2:05

Voiceover

"The safeguard I appreciate most is the filesystem preflight check.

Before a rebuild happens, the script checks what the target host expects for root and boot, compares that to what is actually mounted, and stops if it does not match.

It is very unglamorous, but that is exactly the kind of check that saves you from doing something stupid."

Remotion

Split-screen check:

1. configured root vs mounted root
2. configured boot vs mounted boot

Then show either a green pass or red stop state.

Screen recording

Highlight the relevant lines inside `flakeonly` or `buildall`.

Real-life recording

None.

### Scene 4 - 2:05 to 3:00

Voiceover

"`syncnoctalia` is there because the shell is one of the places where I still want a bit of room to explore and tweak things.

That command pulls the live Noctalia config back into the repo while keeping the host-specific bits intact. So it lets the setup stay lived-in without just drifting off into some totally separate runtime state."

Remotion

Arrow flow from:

`~/.config/noctalia`

back into:

`home/modules/niri/noctalia`

with protected host-specific fields shown as locked.

Screen recording

Show the script logic, then a quick directory view of runtime config and repo config.

Real-life recording

None.

### Scene 5 - 3:00 to 3:55

Voiceover

"`pushconfigs` is basically the practical other half of that.

It stages changes, commits when needed, and pushes them, and it even deals with the slightly awkward sudo plus SSH case. It is one of those things that sounds small, but once it is built into the setup you stop having to think about it."

Remotion

Repo nodes flow into:

1. commit
2. push
3. remote

with a small SSH key icon staying attached through the flow.

Screen recording

Highlight the `pushconfigs` function in the module.

Real-life recording

None.

### Scene 6 - 3:55 to 4:50

Voiceover

"And `buildall` is basically the full ritual in one command.

Sync the shell if I want, verify the target machine, update the flake inputs, rebuild, and then push the result.

I like that a lot, because it means the repo is not only describing the final state. It is also describing the way I move that state forward."

Remotion

Full command pipeline:

1. sync
2. preflight
3. update
4. switch
5. push

Screen recording

Short terminal sequence of the workflow or a mocked clean run.

Real-life recording

None.

### Scene 7 - 4:50 to 5:35

Voiceover

"I also try to keep a sensible boundary around secrets and local-only stuff.

Certificates, credentials, and similar things are left out or injected locally. That is another place where I do not want to pretend the whole world belongs in git just because the system is declarative."

Remotion

Two-column card:

1. tracked in git
2. local only

Screen recording

Show the places where local secrets or placeholders are expected, without exposing anything sensitive.

Real-life recording

None.

### Scene 8 - 5:35 to 6:20

Voiceover

"So that is really the whole setup.

It is not the perfect NixOS configuration, and I am definitely not presenting it as the right way to do things. It is just my setup, built around my machines, my habits, and all the little compromises that came with them.

But that is also exactly why I like it. It feels real."

Remotion

Final recap graph combining:

1. shared structure
2. host exceptions
3. daily UX
4. maintenance ritual

Screen recording

Slow final pass across the repo root.

Real-life recording

Final desk shot with the system running on screen.

## Short Note On Delivery

If you record this script, the main thing to protect is the tone.

Do not read it like a tutorial.
Do not read it like a conference talk.
Read it like you are showing your current setup to people who already know you a bit and are interested in how you actually use your machines.
