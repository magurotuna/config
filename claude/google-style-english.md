# English writing style

Apply these rules whenever you write English prose that people will read:
documentation, READMEs, code comments, doc comments, commit messages, PR and
issue text, review comments, error messages, and other user-facing strings.

- These rules do not choose the conversation language. Reply to the user in the
  language that they use.
- When a project's own style guide or context files conflict with these rules,
  follow the project.
- Apply the rules to text that you write or change. Do not rewrite existing text
  only for style unless the user asks.
- Commit subjects and PR titles keep their own conventions (for example,
  imperative mood or Conventional Commits). The word and sentence rules still
  apply.

Many readers are not native English speakers, and some readers use machine
translation. Write for them. These rules are based on the Google developer
documentation style guide (https://developers.google.com/style), especially
"Write for a global audience" (https://developers.google.com/style/translation),
which is licensed under CC BY 4.0. For cases that these rules do not cover,
follow that guide.

## Words

- Use a simple word: "use", not "utilize" or "leverage"; "start", not
  "commence"; "so", not "consequently".
- Use one word instead of a phrase: "some" or "many", not "a number of".
- Avoid phrasal verbs when a single verb exists: "use", not "make use of";
  "find", not "figure out". Common exceptions are "set up", "log in", and
  "sign in".
- Use each word in one meaning. Avoid "once", "while", "as", and "since" when a
  more exact word exists, such as "after", "although", or "because".
- Use the same term for the same concept everywhere, with the same
  capitalization.
- Avoid idioms, slang, humor, and culture-specific references.
- Avoid Latin abbreviations: "for example", not "e.g."; "that is", not "i.e.".
  List the items instead of writing "etc.".
- Define an abbreviation the first time that you use it.
- Avoid subjective words such as "simply", "just", "easy", "properly", and
  "carefully". State the precise technical detail instead.

## Sentences

- Write short sentences, with one idea in each sentence.
- Use active voice and present tense. Address the reader as "you".
- Use standard word order (subject + verb + object), and put the subject and
  verb near the start of the sentence.
- Put the condition before the instruction: "If X, then do Y."
- Keep the helper words that conversational English drops, such as "that",
  "then", and "of": "the rules that you defined", not "the rules you defined".
- Replace a pronoun with its noun when the pronoun could refer to more than one
  thing.
- Use a clause instead of a gerund phrase when the clause is clearer: "before
  you deploy the VM", not "before deploying the VM".
- Do not use more than two nouns as modifiers of another noun.
- Put "only" directly before the word that it modifies.
- Tell the reader what to do, not only what to avoid.
- Name code elements with a qualifying noun: "the `config.yml` file", "the
  `run` command".

## Formatting

- Use sentence case for headings.
- Use the serial comma.
- Make list items parallel in structure, capitalization, and punctuation.
- Use code font for code elements, commands, file names, and literal values.
- Write dates in an unambiguous format, such as "2026-10-17" or
  "October 17, 2026".
- Put information in text, not only in images.
