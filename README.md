# custom-data (Custom element data)
Custom data system based on Lua tables for MTA:SA, which i've created for myself a few months ago, back in 2020.
I want to thanks for a [very special person](https://github.com/IIYAMA12) which is [IIYAMA](https://forum.mtasa.com/profile/27939-iiyama/), for teaching me tables and trigger related stuff.

# What's that?

A more efficient replacement for internal MTA:SA data system called element data. It is:
- Faster
- Way more adjustable, in terms of sending data, including data reduction techniques such as buffer and batching (things must have, especially when you are dealing with a lot of separated data)
- Provides data handlers, your own functions which will trigger on data change - after meeting certain conditions, which are: element type, data type, key name, and server event.
- Thanks to that, you will be able to process certain logic in many ways (based on data from parameters), without requirement to add separate MTA events.

# Detailed guide, which also covers few important topics
[See forum topic for all details](https://forum.mtasa.com/topic/127520-tut-lua-tables-as-a-efficient-data-system-custom-element-data/)

cos tam
