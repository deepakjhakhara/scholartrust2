const Agent = artifacts.require("Agent");

contract("Agent", (accounts) => {
  const student = accounts[1];
  const teacher = accounts[2];
  const outsider = accounts[3];
  const accessFee = web3.toWei(2, "ether");

  let agent;

  beforeEach(async () => {
    agent = await Agent.new();
    await agent.add_agent("Student A", 30, 0, "hash-1", { from: student });
    await agent.add_agent("Teacher A", 45, 1, "", { from: teacher });
  });

  it("registers student and teacher roles", async () => {
    const p = await agent.get_student.call(student);
    const d = await agent.get_teacher.call(teacher);

    assert.equal(p[0], "Student A");
    assert.equal(d[0], "Teacher A");
  });

  it("enforces exact access fee and credits pool in wei", async () => {
    await agent.permit_access(teacher, { from: student, value: accessFee });
    const pool = await agent.creditPool.call();
    assert.equal(pool.toString(), accessFee.toString());
  });

  it("blocks unauthorized remove_student", async () => {
    await agent.permit_access(teacher, { from: student, value: accessFee });

    try {
      await agent.remove_student(student, teacher, { from: outsider });
      assert.fail("Expected revert for unauthorized caller");
    } catch (error) {
      assert(error.message.includes("revert"), `Expected revert, got ${error.message}`);
    }
  });

  it("lets student revoke access and refunds pool", async () => {
    await agent.permit_access(teacher, { from: student, value: accessFee });
    await agent.revoke_access(teacher, { from: student });

    const pool = await agent.creditPool.call();
    assert.equal(pool.toString(), "0");

    const hasAccess = await agent.hasAccess.call(student, teacher);
    assert.equal(hasAccess, false);
  });
});
