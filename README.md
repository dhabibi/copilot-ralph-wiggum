I made Ralph Wiggum on crack

You need:

1) a git issue tracker to create new issues (Linear, GitHub web UI, a custom Discord/WhatsApp/Telegram chat agent, can even use Claude Code or Opencode to create issues via CLI, can use Poke to create issues in Linear that get turned into git issues...)
2) A coding agent of choice that you can @ on GitHub by assigning an issue to it (@copilot, @codex, @claude all work)
3) A code review model of choice that you can @ on GitHub (I prefer @codex)
4) A GitHub Action loaded into your repo (I had Claude make this, and this is what I'm sharing here with instructions)

To work on your project, you simply create a Git repo if none exists. 

You can work with your model of choice to create detailed issues, or your human managers/PMs can do it too.

You can post one issue at a time, or a bunch of different ones all at once if they're mutually exclusive (try to avoid merge conflict hell, this is purely a skill issue with regards to your ability to break down tasks well)

What I had done before manually is:

1) I create an issue (either myself or via CLI thru Claude Code) and assign it to Copilot
2) Copilot begins working, implements the issue, and eventually pings me for review
upon getting pinged once Copilot is actually done working, I post "@codex review"
3) If Codex finds an issue or 2, I post "@Copilot address that issue"
4) I repeat 2 and 3 until Codex stops finding issues, and then I merge.

What this github action does is it Ralph Wiggums this process - it automates this into a loop, so that the only piece of human interaction needed is creating an issue and assigning it to an agent that's capable of opening a PR and implementing it.

The benefit of doing this on github itself via copilot and other agents available there is that:

a) codex is the best bug finding ai period, it's superhuman at that and code review. I can leverage it using my $20 sub

b) I can also use claude via copilot there for $10. Or I can use a Claude sub. Or really any other agent sub by modifying the @ command

c) I dont have to have a long running session on my pc or anything. I can just make the git issue from anywhere and the feature gets built 

d) it plays nicely with any Cl/CD, any issue tracking system that already exists, literally any existing piece of software that already has git integrations (which is every serious piece of tech project management software ever made)

I actually think this is going to be superior to terminal based CLI coding for MOST people. And, if you’re already well versed in CLI coding, you can still hook into this and coordinate a disgusting amount of agents by automatically creating issues via CLI or via any chatbot.
