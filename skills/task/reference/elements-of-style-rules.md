# Elements of Style — copyedit rules

A distillation of William Strunk Jr.'s _The Elements of Style_ for copyediting prose in plan files.

---

## Rules

**Rule 10: Use active voice.**
Bad: "The file must be read by the agent."
Good: "The agent reads the file."

**Rule 11: Put statements in positive form.**
Bad: "Don't forget to add tests."
Good: "Add tests."

**Rule 12: Use definite, specific, concrete language.**
Bad: "Process the data in the module."
Good: "Parse the JSON response in `src/api/parser.ts:45`."

**Rule 13: Omit needless words.**
Bad: "In order to ensure correct system operation, it is necessary to perform validation."
Good: "Validate the input."

**Rule 16: Keep related words together.**
Bad: "Add, to the component that renders the user list, pagination."
Good: "Add pagination to the user-list component."

**Rule 18: Place emphatic words at end of sentence.**
Bad: "It is critical that the middleware handles errors."
Good: "The middleware handles errors — that matters most."

---

## Application

For every sentence in the plan file:

1. Active voice?
2. Positive form?
3. Concrete language (files, lines, names)?
4. Can any words be cut without losing meaning?
5. Related words next to each other?
6. The emphatic word at the end?
