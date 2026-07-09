# 01 — Requirements Analysis

Source spreadsheets: [`../../requirements/StakeholderNeeds.xlsx`](../../requirements/StakeholderNeeds.xlsx), [`../../requirements/SystemRequirements.xlsx`](../../requirements/SystemRequirements.xlsx).
Imported into Requirements Toolbox sets: [`../requirements/StakeholderNeeds.slreqx`](../requirements/StakeholderNeeds.slreqx), [`../requirements/SystemRequirements.slreqx`](../requirements/SystemRequirements.slreqx).

## 1. Stakeholder needs (SN-GS-001..015)

| ID | Summary | Description | Rationale |
|---|---|---|---|
| SN-GS-001 | Soup menu | Kitchen shall produce a menu of distinct soup varieties selectable by operators. | Customers expect variety across the menu. |
| SN-GS-002 | Small crew | Kitchen shall be operable by the small crew of beings on site. | Only 5 beings staff the facility. |
| SN-GS-003 | Galactic shipping | Kitchen shall dispatch finished soup to customers across the galaxy. | Customers are distributed across many worlds. |
| SN-GS-004 | Food safety | Kitchen shall deliver safe, uncontaminated soup at correct serving temperature. | Safety and quality are non-negotiable. |
| SN-GS-005 | Transit-durable packaging | Packaging shall keep soup intact during long-distance interstellar transit. | Shipments take weeks to reach far customers. |
| SN-GS-006 | Inventory tracking | Kitchen shall track ingredient stock so the crew knows what to reorder. | Stock-outs halt production; crew needs visibility. |
| SN-GS-007 | Facility budgets | Kitchen shall fit within facility mass, volume, power, and cost budgets. | Deployment site imposes hard resource limits. |
| SN-GS-008 | Gravity range | Kitchen shall operate across the range of gravitational environments where customer worlds are located. | Facility may be deployed on any of a diverse set of worlds. |
| SN-GS-009 | Delivery fleet support | Kitchen shall operate and include a fleet of delivery rockets for transporting finished soup to customers and receiving inbound deliveries. | Dedicated infrastructure required for frequent launch, landing, loading, and refueling operations. |
| SN-GS-010 | Ingredient storage | Kitchen shall store a variety of delivered ingredients under appropriate temperature and handling conditions. | Need safe, flexible storage of both perishable and shelf-stable ingredients. |
| SN-GS-011 | Cooking infrastructure | Kitchen shall include cooking infrastructure capable of producing soup at required production rates. | Throughput targets cannot be met without sufficient cooking capacity matched to demand. |
| SN-GS-012 | Internal material transport | Kitchen shall transport ingredients and products internally between receiving, storage, cooking, packaging, and delivery areas. | Required to meet throughput targets. |
| SN-GS-013 | Operational lifecycle | Kitchen shall support startup, steady operation, and shutdown across its deployment lifecycle. | System must operate safely outside of nominal steady-state conditions. |
| SN-GS-014 | Fault tolerance | Kitchen shall continue operating or degrade safely in the presence of faults. | Production continuity and safety must be maintained with minimal crew intervention. |
| SN-GS-015 | System coordination | Kitchen shall coordinate cooking, packaging, storage, and transport activities to meet operational goals. | High automation requires integrated system-level control. |

## 2. System requirements (SR-GS-001..028)

| ID | Summary | Description | Derived from |
|---|---|---|---|
| SR-GS-001 | Recipe count | Cook at least 8 distinct recipes selectable at runtime. | SN-GS-001 |
| SR-GS-002 | Throughput | Sustain total throughput of at least 200 bowls/hour. | SN-GS-001 |
| SR-GS-003 | Automation level | Achieve average automation level of at least 0.8 across components. | SN-GS-002 |
| SR-GS-004 | Operator count | Require at most 5 concurrent operators at peak load. | SN-GS-002 |
| SR-GS-005 | Shipping manifest | Generate a shipping manifest per batch including destination. | SN-GS-003 |
| SR-GS-006 | Transport loading time | Load packaged soup onto transport within 10 minutes of packaging. | SN-GS-003 |
| SR-GS-007 | Contamination detection | Detect contamination before sealing with at least 99% sensitivity. | SN-GS-004 |
| SR-GS-008 | Serving temperature | Verify soup temperature in 70-95 °C before QC sign-off. | SN-GS-004 |
| SR-GS-009 | Container seal life | Seal containers rated for 30-day interstellar transit. | SN-GS-005 |
| SR-GS-010 | Inventory accuracy | Track ingredient inventory with at most 1% stock error. | SN-GS-006 |
| SR-GS-011 | Mass budget | Total system mass shall not exceed 15,000 kg. | SN-GS-007 |
| SR-GS-012 | Power budget | Total system power draw shall not exceed 500 kW. | SN-GS-007 |
| SR-GS-013 | Cost budget | Total system cost shall not exceed 2,000,000 credits. | SN-GS-007 |
| SR-GS-014 | Volume budget | Total system volume shall not exceed 400 m³. | SN-GS-007 |
| SR-GS-015 | Gravity operating range | Perform all cooking, packaging, and shipping functions nominally across ambient gravity 0.1 g to 12 g. | SN-GS-008 |
| SR-GS-016 | Structural 12 g tolerance | System structure and mounts shall withstand sustained 12 g loading without permanent deformation. | SN-GS-008 |
| SR-GS-017 | Concurrent rocket support | Support simultaneous handling of at least 3 delivery rockets for loading or unloading. | SN-GS-009 |
| SR-GS-018 | Rocket turnaround | Complete loading or unloading of a delivery rocket within 20 minutes. | SN-GS-009 |
| SR-GS-019 | Rocket refueling | Provide on-site refueling capability for supported delivery rockets. | SN-GS-009 |
| SR-GS-020 | Temperature-controlled storage | Provide separate storage zones for cold and room-temperature ingredients. | SN-GS-010 |
| SR-GS-021 | Ingredient storage capacity | Store at least 72 hours of ingredients at nominal production rate. | SN-GS-010 |
| SR-GS-022 | Cooking capacity | Cook soup at a sustained rate sufficient to meet overall throughput requirements. | SN-GS-011 |
| SR-GS-023 | Internal transfer time | Transport ingredients from storage to cooking at a rate sufficient to sustain nominal cooking throughput. | SN-GS-012 |
| SR-GS-024 | Internal transport automation | Internal material transport shall be automated for at least 90% of transfers. | SN-GS-012 |
| SR-GS-025 | Startup readiness | Reach nominal operating throughput within a defined startup period after activation. | SN-GS-013 |
| SR-GS-026 | Fault-induced throughput degradation | Prevent uncontrolled termination of production due to single internal component faults. | SN-GS-014 |
| SR-GS-027 | Production coordination | Coordinate internal operations to satisfy throughput, safety, and logistical constraints concurrently. | SN-GS-015 |
| SR-GS-028 | Preparation zone | Include a separate ingredient preparation zone (chopping, weighing) physically isolated from storage and cooking, sustaining prep throughput of at least 200 bowls/hour equivalent. | SN-GS-001 |

## 3. Derive-link traceability (SN → SR)

| Stakeholder need | Derived system requirements |
|---|---|
| SN-GS-001 Soup menu | SR-GS-001, SR-GS-002, SR-GS-028 |
| SN-GS-002 Small crew | SR-GS-003, SR-GS-004 |
| SN-GS-003 Galactic shipping | SR-GS-005, SR-GS-006 |
| SN-GS-004 Food safety | SR-GS-007, SR-GS-008 |
| SN-GS-005 Transit-durable packaging | SR-GS-009 |
| SN-GS-006 Inventory tracking | SR-GS-010 |
| SN-GS-007 Facility budgets | SR-GS-011, SR-GS-012, SR-GS-013, SR-GS-014 |
| SN-GS-008 Gravity range | SR-GS-015, SR-GS-016 |
| SN-GS-009 Delivery fleet support | SR-GS-017, SR-GS-018, SR-GS-019 |
| SN-GS-010 Ingredient storage | SR-GS-020, SR-GS-021 |
| SN-GS-011 Cooking infrastructure | SR-GS-022 |
| SN-GS-012 Internal material transport | SR-GS-023, SR-GS-024 |
| SN-GS-013 Operational lifecycle | SR-GS-025 |
| SN-GS-014 Fault tolerance | SR-GS-026 |
| SN-GS-015 System coordination | SR-GS-027 |

Every stakeholder need has at least one derived system requirement, and every system requirement traces back to exactly one stakeholder need; there is no orphaned SR. Note that SN-GS-001 (soup menu) fans out to three SRs spanning recipe variety, aggregate throughput, and the dedicated prep zone — reflecting that "menu variety at volume" is the single most architecturally demanding stakeholder need.

## 4. Key driving requirements and architectural implications

These requirements exert outsized influence on the physical architecture and are the primary axes of the physical-layer trade study (see [`04_physical_variants.md`](04_physical_variants.md)):

- **Facility budgets (SR-GS-011..014 — mass ≤ 15,000 kg, power ≤ 500 kW, cost ≤ 2,000,000 credits, volume ≤ 400 m³).** Hard resource ceilings that every physical variant must respect. They directly motivate a resource-budget-optimized variant (LeanBroth) as a design point, and constrain how much redundancy or automation the throughput- and resilience-optimized variants (HyperCook, EverSimmer) can afford.
- **Throughput (SR-GS-002 — 200 bowls/hour) and cooking capacity (SR-GS-022) and prep zone throughput (SR-GS-028 — 200 bowls/hour equivalent).** Sets the sizing target for cooking, prep, and internal transport capacity end-to-end; no stage may bottleneck the chain. Drives the throughput-optimized variant (HyperCook) and its parallel cook/prep lines.
- **Gravity range (SR-GS-015, SR-GS-016 — 0.1 g to 12 g, structural).** Forces an explicit gravity-compensation function/component (see ADR-005) and drives structural and mounting margin in every physical variant, independent of which variant is selected.
- **Concurrent rocket handling and turnaround (SR-GS-017, SR-GS-018, SR-GS-019 — 3 concurrent rockets, 20-minute turnaround, on-site refueling).** Sizes the shipping/launch complex; a major differentiator between the four-pad automated gantry approach (HyperCook), the shared three-pad crane approach (LeanBroth), and the three independent single-pad cells (EverSimmer).
- **Fault tolerance (SR-GS-026 — no single-fault production kill) and automation (SR-GS-003, SR-GS-024 — ≥0.8 average automation, ≥90% transport automation).** Motivates the resilience-optimized variant (EverSimmer) with independent production cells and redundant power/control, at the cost of higher mass/cost per unit throughput.
- **Small crew (SN-GS-002; SR-GS-003, SR-GS-004 — ≤5 operators, ≥0.8 automation).** Constrains every variant to be predominantly automated; the variants differ in how close to the 5-operator ceiling they run and in operator role (LeanBroth uses all 5 in a more human-in-the-loop mode, EverSimmer needs only 2 due to higher automation).
