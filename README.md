# Neuryt

Semi-opinionated CQRS+ES framework.

Neuryt was created as a way for me to learn more about Event Sourcing
and CQRS and gain experience in both implementing the framework for
those techniques and using them in an application.  
Ultimately, my company canceled the project for which Neuryt was being
created and working on this was not needed any more.

## _Side note_

Even in that unfinished form, Neuryt did learning experience. CQRS+ES
can create a cleaner code, especially if you use discriminated unions
(I used my x4lldux/disc_union library for this). But more easily it
can crate a lot of head scratching (with eventual consistency or where
to place a functionality), boilerplate and code that is more tangled
in less obvious ways -- events are coupling too, but a one that
compiler, dializer nor editors can't track for you. Don't start with
it.
