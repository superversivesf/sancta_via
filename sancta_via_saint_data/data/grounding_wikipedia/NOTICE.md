# Wikipedia grounding corpus — licensing notice

The plain-text files and `manifest.json` in this directory were scraped from
English Wikipedia via the MediaWiki API (`prop=extracts&explaintext=1`).

- Source licensing: Wikipedia article text is available under the
  Creative Commons Attribution-ShareAlike 4.0 International License
  (https://creativecommons.org/licenses/by-sa/4.0/) and the GNU Free
  Documentation License.
- Adaptation notice: the grounded saint histories derived from these texts
  (in `data/histories.json`, wikipedia class) are adaptations of Wikipedia
  text and are distributed under the same Creative Commons
  Attribution-ShareAlike 4.0 International License, with the attribution
  line `Adapted from Wikipedia (CC BY-SA 4.0)` per the source-class
  registry in `lib/src/utils/history_source.dart`.
- Changes: the histories are edited summaries (grounding excerpts, hedged
  "tradition holds" claims, prompt-level length bounds), not verbatim
  copies; each carries its source URL in `historySource`.
- Catholic Encyclopedia (1907–12) texts in `data/grounding/` are public
  domain (via newadvent.org) and carry their own attribution line.
