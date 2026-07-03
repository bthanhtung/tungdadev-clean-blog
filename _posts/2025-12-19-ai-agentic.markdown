---
layout: post
title: "ai agentic systems"
date: 2025-12-19 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, ai, best-practices, vietnamese]
---

### # ai agent là gì?

Chatbot trả lời câu hỏi. AI Agent **giải quyết vấn đề**.

Sự khác biệt cốt lõi: chatbot reactive (hỏi → trả lời → xong), agent proactive (nhận goal → lập kế hoạch → thực thi multi-step → tự sửa sai → deliver kết quả). Agent có **agency** — khả năng tự quyết định hành động tiếp theo dựa trên kết quả hành động trước.

```
Chatbot:
User: "Cách fix NullPointerException?"
Bot:  "Check null trước khi access..." → DONE

AI Agent:
User: "Fix bug PORTAL-123"
Agent: (thinking) "Cần hiểu bug → đọc ticket → xem code → tìm root cause → fix → test → PR"
 Step 1: Đọc Jira ticket PORTAL-123 → hiểu symptom
 Step 2: Tìm file liên quan trong codebase
 Step 3: Đọc code, identify root cause
 Step 4: Viết fix
 Step 5: Chạy tests
 Step 6: Tests fail → đọc error → sửa lại
 Step 7: Tests pass → tạo PR
 → DONE (multi-step, self-correcting)
```

#### # spectrum of ai autonomy

```
Level 0: Chatbot          → Q&A, no actions
Level 1: Tool-augmented   → Answer + call 1 tool khi cần
Level 2: Multi-step agent → Plan + execute sequence of tools
Level 3: Autonomous agent → Self-plan, self-correct, handle errors, create sub-goals
Level 4: Multi-agent      → Nhiều agents collaborate, delegate, review nhau
```

Hầu hết tools hiện tại (GitHub Copilot, Cursor, Kiro) hoạt động ở Level 2-3. Multi-agent systems (Level 4) đang emerging nhưng chưa mainstream production.

### # anatomy of an ai agent

Mọi agent đều có 4 thành phần

![ai-component](/assets/img/blog/ai/ai-component.png)

#### # brain (llm)

Quyết định hành động tiếp theo. LLM nhận current state (conversation + observations + tools available) và output: "tôi nên dùng tool nào, với params gì."

Chất lượng agent phụ thuộc vào:

- Model capability (reasoning, instruction following)
- System prompt (personality, constraints, workflow)
- Temperature (0 = deterministic, cao = creative/risky)

#### # memory

- **Short-term**: Conversation history (limited by context window)
- **Working memory**: Notes agent tự ghi (scratchpad, intermediate results)
- **Long-term**: Knowledge base, vector store, previous interactions

Khi context window đầy (100K-200K tokens), agent cần strategy: summarize older context, store important facts externally, hoặc split task thành smaller subtasks.

#### # tools

Actions agent có thể thực hiện. Trong development context:

- Read/write files
- Run shell commands
- Search codebase
- Call APIs (Jira, Confluence, GitHub)
- Run tests
- Create git branches/commits/PRs
- Web search for documentation

Tools = MCP servers + built-in capabilities.

### # agent loop — react pattern

Pattern phổ biến nhất: **ReAct** (Reasoning + Acting). Agent alternates giữa thinking (reasoning about what to do) và acting (executing a tool).

![agent-loop](/assets/img/blog/ai/agent-loop.png)

Phân tích cơ chế ReAct qua ví dụ:
Tự quản lý Trạng thái (State Management): Qua mỗi Iteration, phần OBSERVATION từ môi trường (Codebase, Compiler)
đóng vai trò là "nhiên liệu" mới nạp vào Context Window của LLM. Agent dựa vào đó để "nghĩ" (THOUGHT) xem bước tiếp theo
cần làm gì, thay vì chạy một kịch bản hard-code sẵn.

Cơ chế Đóng vòng lặp (Convergence): Ở Iteration 5 và 6, Agent không dừng lại ngay sau khi sửa code (edit_file).
Nó chủ động thực hiện hành động Kiểm định chất lượng (run_command để chạy test và get_diagnostics để check linter).
Đây là điểm phân biệt lớn nhất giữa một AI Agent và một con Bot sinh Code thông thường: Agent có trách nhiệm với kết quả đầu ra của mình.

#### # pseudo-code của agent loop:

```python
def agent_loop(user_request, max_iterations=20):
   messages = [system_prompt, user_request]
   tools = get_available_tools()

   for i in range(max_iterations):
       # LLM decides next action
       response = llm.generate(messages, tools=tools)

       if response.is_final_answer():
           return response.text  # Done — return to user

       if response.has_tool_calls():
           for tool_call in response.tool_calls:
               # Execute tool
               result = execute_tool(tool_call.name, tool_call.arguments)

               # Add observation to context
               messages.append({"role": "tool", "content": result})

       # Loop continues — LLM sees observation, decides next step

   return "Reached max iterations without completing task"
```

### # planning strategies — cách agent lập kế hoạch

#### # strategy 1: step-by-step (react)

Đơn giản nhất: mỗi iteration, decide 1 step. Không plan ahead toàn bộ.

- Pro: Flexible, adapt to observations
- Con: Có thể loop, lose track of big picture

#### # strategy 2: plan-then-execute

Agent tạo full plan trước, execute step-by-step, revise plan nếu cần.

```
User: "Refactor UserService to use Clean Architecture"

PLAN:
1. Read current UserService and dependencies
2. Create domain layer (entities, ports)
3. Create use case layer
4. Create adapter layer (current service becomes adapter)
5. Update controller to use ports
6. Move tests to match new structure
7. Run tests, fix issues
8. Verify no regressions

EXECUTION:
[Step 1] Reading files... ✓
[Step 2] Creating domain/model/User.java... ✓
[Step 3] Creating domain/port/UserRepository.java... ✓
[Step 4] Oh, UserService also depends on EmailService → revise plan
REVISED PLAN: Add step 3.5: Create NotificationPort
[Step 3.5] Creating domain/port/NotificationPort.java... ✓
...
```

#### # strategy 3: hierarchical (decompose → delegate)

Complex tasks broken into subtasks, each handled independently (potentially by sub-agents).

```
Main Agent: "Build user registration feature"
 ├── Sub-task 1: "Design data model" → Research Agent
 ├── Sub-task 2: "Implement API endpoint" → Coding Agent
 ├── Sub-task 3: "Write tests" → Testing Agent
 └── Sub-task 4: "Update documentation" → Docs Agent
```

### # multi-agent systems

Thay vì 1 super-agent làm mọi thứ, chia thành nhiều specialized agents collaborate:

![multi-agent](/assets/img/blog/ai/multi-agent.png)

Orchestrator Agent (Gốc): Đóng vai trò là "Manager" (Quản lý). Nó nhận yêu cầu lớn từ User, bẻ nhỏ bài toán (Task Decomposition),
giao việc cho các Agent chuyên môn và là người cuối cùng duyệt nghiệm thu kết quả trước khi trả về cho khách hàng.

Research Agent: Tập trung thu thập thông tin, tìm hiểu tài liệu kỹ thuật hoặc cấu trúc hệ thống.

Coder Agent: Chỉ tập trung vào việc tạo ra giải pháp kỹ thuật, viết mã nguồn dựa trên các thông tin mà tầng trên cung cấp.

Reviewer Agent: Đóng vai trò kiểm soát chất lượng (QA/QC), phản biện độc lập để đảm bảo mã nguồn tối ưu,
không dính lỗ hổng bảo mật trước khi cho phép tích hợp.

#### # khi nào multi-agent?

| Scenario                                                        | Single Agent   | Multi-Agent            |
| --------------------------------------------------------------- | -------------- | ---------------------- |
| Simple task (fix typo)                                          | ✓              | Overkill               |
| Medium task (add feature)                                       | ✓              | Optional               |
| Complex task (full feature, design + implement + test + review) | Struggles      | ✓                      |
| Tasks needing different expertise                               | Limited        | ✓ (specialized agents) |
| Tasks needing checks & balances                                 | No self-review | ✓ (reviewer agent)     |

#### # communication patterns:

```
1. Sequential Pipeline:
  Research → Code → Test → Review → Deploy
  (mỗi agent output = input cho agent tiếp)

2. Collaborative:
  Coder writes → Reviewer feedback → Coder revises → Reviewer approves
  (iterative loop giữa 2 agents)

3. Hierarchical:
  Orchestrator delegates subtasks → sub-agents report back
  (tree structure)

4. Debate:
  Agent A proposes solution → Agent B critiques → Agent A defends/revises
  (adversarial — better quality through disagreement)
```

### # agentic patterns trong development (2025)

#### # pattern 1: code generation agent

```
Input: Natural language requirement
Process: Understand → Plan → Generate code → Run tests → Iterate
Output: Working code with tests

Tools needed: file read/write, run tests, search codebase, get diagnostics
```

#### # pattern 2: bug investigation agent

```
Input: Bug report (Jira ticket, error log)
Process: Read report → Find relevant code → Reproduce → Identify root cause → Suggest fix
Output: Root cause analysis + proposed fix

Tools needed: Jira (read ticket), codebase search, file read, run tests
```

#### # pattern 3: code review agent

```
Input: Git diff / Pull Request
Process: Read changes → Check quality → Identify issues → Suggest improvements
Output: Review comments

Tools needed: Git diff, file read, run linter, security scan
```

#### # pattern 4: documentation agent

```
Input: Code changes or feature spec
Process: Read code → Understand intent → Generate/update docs → Verify accuracy
Output: Updated documentation

Tools needed: file read/write, search, Confluence API
```

#### # pattern 5: spec-driven development agent

```
Input: Feature idea
Process:
 Phase 1: Generate requirements (ask clarifying questions)
 Phase 2: Design architecture
 Phase 3: Create task breakdown
 Phase 4: Implement tasks (code + test each)
 Phase 5: Review implementation
Output: Complete feature with docs and tests

Tools needed: ALL (file ops, tests, git, Jira, Confluence, web search)
```

### # challenges & limitations

#### # hallucination in action

Agent "confident" gọi tool với wrong parameters, hoặc claim file exists khi không:

```
// Agent thinks test passed but actually read old output
THOUGHT: "Tests pass, I'm done"
REALITY: Tests were from previous run, current code has bug

// Mitigation: ALWAYS re-run, never trust cached results
```

#### # infinite loops

Agent stuck — retrying same approach that keeps failing:

```
Iteration 5: Try approach A → fails
Iteration 6: Try approach A (slightly different) → fails
Iteration 7: Try approach A (again) → fails
...

// Mitigation: Loop detection, max iterations, escalate after N failures
```

#### # context window exhaustion

Long tasks accumulate context → window full → agent "forgets" earlier steps:

```
// Mitigation strategies:
1. Summarize completed steps (compress context)
2. External memory (write notes to file, read when needed)
3. Task decomposition (smaller subtasks = less context per subtask)
4. Context compaction (automatic in modern systems)
```

#### # safety & unintended actions

Agent có tools powerful → có thể cause damage:

```
// Dangerous: Agent decides to "clean up" by deleting files
// Dangerous: Agent runs `rm -rf` thinking it's temp directory
// Dangerous: Agent pushes directly to main branch

// Mitigation:
1. Approval gates (human confirms before destructive actions)
2. Sandboxing (agent operates in isolated environment)
3. Guardrails (system prompt: "never delete without confirmation")
4. Reversibility preference (prefer reversible actions)
```

### # building effective agents — best practices

#### # system prompt design

```
Good system prompt includes:
1. Identity: "You are a senior Java developer..."
2. Capabilities: "You can read files, write code, run tests..."
3. Constraints: "Never push to main, always run tests before claiming done"
4. Workflow: "Read before writing, test after coding, verify before reporting"
5. Style: "Match existing code style, follow project conventions"
6. Failure handling: "If stuck after 2 attempts, try different approach"
```

#### # tool design for agents

```
Good tool design:
- Clear, specific descriptions (AI uses description to decide WHEN to use)
- Atomic actions (1 tool = 1 thing)
- Informative return values (agent needs to understand result)
- Error messages that guide next action
- Idempotent where possible

Bad tool design:
- Vague description: "Do stuff with files" (when does AI use this?)
- God tool: "manage_everything(action, params)" (too many options)
- Silent failures: return empty on error (agent thinks success)
```

#### # evaluation & improvement

```
How to measure agent quality:
1. Task completion rate (% tasks fully completed correctly)
2. Iteration efficiency (steps needed vs optimal)
3. Error recovery rate (% of errors self-corrected)
4. Tool usage accuracy (right tool, right params)
5. Safety (0 destructive unintended actions)

Improvement loop:
1. Collect failed tasks
2. Analyze failure patterns (wrong tool? bad reasoning? missing context?)
3. Improve: system prompt, tool descriptions, or add new tools
4. Re-test
```

### # tương lai (2025-2027)

| Trend                                | Status         | Impact                            |
| ------------------------------------ | -------------- | --------------------------------- |
| Longer context windows (1M+ tokens)  | Happening now  | Less context management needed    |
| Better reasoning models (o1, o3)     | Available      | More complex multi-step tasks     |
| Native tool use in models            | Improving      | Fewer hallucinated tool calls     |
| Multi-modal agents (code + visual)   | Emerging       | UI testing, diagram understanding |
| Agent-to-agent protocols             | Early research | Standardized multi-agent collab   |
| Continuous learning                  | Research       | Agents improve from past tasks    |
| Formal verification of agent actions | Research       | Safety guarantees                 |

**Bottom line**: AI Agents đang transition từ "cool demo" sang "production tool." Developer không cần become AI researcher — nhưng cần hiểu cách leverage agents effectively: design good tools, write good prompts, set up guardrails, và know when to trust vs verify agent output.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
