# Documentation Structure Concepts

Background on documentation organization approaches and when to use each.

## Two Main Approaches

### Category-Based (Diátaxis)

Organize by documentation type:

```
docs/
├── tutorials/    # Learning-oriented
├── guides/       # Task-oriented
├── reference/    # Information-oriented
└── explanation/  # Understanding-oriented
```

The [Diátaxis framework](https://diataxis.fr/) by Daniele Procida identifies four types of documentation, each serving a different user need:

| Type | Purpose | User Question |
|------|---------|---------------|
| Tutorials | Learn by doing | "Teach me" |
| How-to Guides | Accomplish a task | "How do I...?" |
| Reference | Look up details | "What is...?" |
| Explanation | Understand concepts | "Why...?" |

**Advantages:**
- Clear purpose for each section
- Readers know where to look
- Scales well for large doc sets
- Encourages complete coverage

**Challenges:**
- Overhead for small projects
- Can separate related content
- Requires discipline to maintain

### Topic-Based

Organize by subject, using suffixes to indicate type:

```
docs/
├── authentication.md           # Overview
├── authentication-guide.md     # How to set up
├── authentication-reference.md # API details
└── database.md                 # Different topic
```

**Advantages:**
- Related content stays together
- Simpler for small doc sets
- Easier to navigate by topic
- Natural for package documentation

**Challenges:**
- Less clear structure
- Can become disorganized at scale
- Type boundaries less obvious

## When to Use Each

### Use Category-Based When:

- Documentation exceeds 20+ pages
- Multiple distinct audiences (users vs developers)
- Comprehensive reference documentation exists
- Dedicated documentation team maintains it
- Project has tutorials, guides, AND reference

### Use Topic-Based When:

- Documentation is small to medium
- Single primary audience
- Each topic is self-contained
- Developers write docs alongside code
- Package or library documentation

## Hybrid Approach

Metool uses a hybrid:

- **Metool core**: Category-based with `reference/`, `guides/`, `conventions/`
- **Metool packages**: Topic-based with `-guide`, `-reference` suffixes

This balances structure for the core project with simplicity for packages.

## The Four Documentation Types

Understanding these types helps regardless of which structure you use:

### 1. Tutorials (Learning)

- Walk through from start to finish
- "Follow along and do this"
- Designed for beginners
- Example: "Getting Started with Metool"

### 2. How-to Guides (Tasks)

- Steps to accomplish specific goals
- "How do I configure X?"
- Assumes some knowledge
- Example: "How to Create a Service Package"

### 3. Reference (Information)

- Technical descriptions
- Complete, accurate, concise
- For looking things up
- Example: Command reference, API docs

### 4. Explanation (Understanding)

- Background and context
- "Why does this work this way?"
- Discusses alternatives and tradeoffs
- Example: This document

## Practical Tips

1. **Start simple** - Begin with topic-based, add structure as needed
2. **Don't force it** - Not every doc fits neatly into one type
3. **Cross-link** - Connect related content regardless of structure
4. **README as hub** - Use README.md files to navigate any structure
5. **Evolve gradually** - Reorganize when pain points emerge

## Further Reading

- [Diátaxis](https://diataxis.fr/) - The original framework
- [Write the Docs](https://www.writethedocs.org/) - Documentation community
- [Google Developer Documentation Style Guide](https://developers.google.com/style)
