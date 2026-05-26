# Azure for Students Subscription – Plan & Overview

> **Audience**: Students evaluating or activating the Azure for Students subscription.  
> **Purpose**: Consolidate offer details, risks, and an action plan into a single decision-support reference.  
> **Last Verified**: 2026-05-26  
> **Owner**: v-gangulysa  
> **Review Cadence**: Quarterly (or when Microsoft updates offer terms)

## 1. What is Azure for Students?

Azure for Students is a free Microsoft Azure subscription designed for verified full-time students at accredited degree-granting institutions. It provides cloud resources for learning, academic research, and educational projects — without requiring a credit card.

## 2. Key Benefits

| Benefit | Details |
|---------|---------|
| Free Credit | $100 USD valid for 12 months |
| No Credit Card | Sign up with verified academic email only |
| Free Services (12 months) | 20+ popular services with monthly free tiers (VMs, SQL, Blob Storage, etc.) |
| Always-Free Services | 65+ services at perpetual free tier |
| Developer Tools | Visual Studio, VS Code, Azure DevOps, SQL Server Developer Edition |
| Renewal | Annual renewal while student status is maintained |

## 3. Eligibility Requirements

- Must be **18 years or older**
- Must be a **full-time student** at an accredited two- or four-year degree-granting institution
- Must verify via **institutional (.edu or equivalent) email**
- **Not available** for MOOC enrollees or professional training at for-profit organizations
- Limited to **one active subscription per student**
- Cannot be combined with other Azure offers unless explicitly allowed

## 4. Included Services (Highlights)

- **Compute**: 750 hours/month each for B1S Linux VMs and B1S Windows VMs (one VM running continuously ≈ 730 hours/month)
- **Database**: 32 GB Azure SQL Database (up to 10 free serverless databases, General Purpose tier)
- **Storage**: Azure Blob Storage (free tier)
- **Web**: 10 web/mobile/API apps on Azure App Service
- **Serverless**: 1 million executions/month with Azure Functions
- **AI/ML**: Azure Machine Learning Studio, Cognitive Services (limited)
- **IoT**: Microsoft IoT Hub
- **NoSQL**: Cosmos DB (limited free tier)
- **Monitoring**: Application Insights
- **DevOps**: Azure DevOps (free tier — see Section 4.1 below)

### 4.1 Azure DevOps – Free Tier Details

Azure DevOps is included with Azure for Students and provides a full DevOps toolchain at no cost for small teams:

| Service | Free Tier Limits |
|---------|-----------------|
| **Users** | 5 Basic users + unlimited Stakeholders (view-only roles) |
| **Azure Repos** | Unlimited private Git repositories |
| **Azure Pipelines** | 1 Microsoft-hosted parallel job (1,800 min/month) + 1 self-hosted parallel job (unlimited minutes) |
| **Azure Boards** | Full agile project management — Kanban, sprints, backlogs, work items |
| **Azure Artifacts** | 2 GiB package storage per organization (NuGet, npm, Python, Maven) |
| **Azure Test Plans** | Not included in free tier |

**Key capabilities for students:**

- **CI/CD Pipelines** — Automate builds, tests, and deployments using multi-stage YAML pipelines. Supports .NET, Java, Node.js, Python, Go, and more.
- **Git Repos** — Unlimited private repos with pull requests, branch policies, and code review workflows.
- **Boards** — Track work items, plan sprints, and manage backlogs with customizable workflows.
- **Artifacts** — Host private package feeds for your project dependencies.
- **Integration** — Tight integration with VS Code, Visual Studio, GitHub, and Azure services.

**Limitations to note:**

- Beyond 5 Basic users → $6/user/month
- Microsoft-hosted pipeline minutes are capped at 1,800/month (≈30 hours); self-hosted agents have no minute cap
- Extra parallel jobs and artifact storage beyond 2 GiB cost extra
- New organizations may need to [request free pipeline grants](https://aka.ms/azpipelines-parallelism-request) before pipelines run

**Best student use cases:**

- Setting up CI/CD for class projects or portfolio apps
- Learning agile/scrum methodologies with real tooling
- Hosting private repos for group projects
- Publishing reusable packages (npm, NuGet) for shared libraries

## 5. Limitations & Risks

| Limitation | Impact |
|------------|--------|
| $100 credit cap | Subscription disabled once exhausted; resources deleted after ~90 days if not upgraded to Pay-As-You-Go |
| Non-transferable | Credits/subscription cannot be shared or moved |
| No carry-over | Unused credit does not roll into next renewal period |
| Educational use only | Not for commercial/production workloads |
| Regional availability | Limited activation pool in some regions |
| No SLA | No production SLA guarantees |
| VM restrictions | Some VM sizes/SKUs and regions unavailable |
| Marketplace | Cannot purchase marketplace offerings |

## 6. Recommended Use Cases

1. **Learning & Experimentation** – Spin up VMs, try Kubernetes, explore AI services
2. **Academic Projects** – Host student project apps, databases, APIs
3. **Certifications** – Practice for AZ-900, AZ-204, and other Azure exams
4. **Hackathons** – Quick prototyping with real cloud infrastructure
5. **Portfolio Building** – Deploy personal projects to demonstrate cloud skills

## 7. What to Avoid

- Running always-on production workloads (credit will drain fast)
- Storing critical/irreplaceable data without backups (sub gets disabled at $0)
- Using for commercial purposes (violates terms)
- Assuming resources persist after credit exhaustion

## 8. Upgrade Path

When credits expire or you graduate:
1. **Upgrade to Pay-As-You-Go** – keeps resources running; charges begin
2. **Azure Free Account** – separate offer with $200/30 days (requires credit card)
3. **Visual Studio Enterprise subscription** – if available through employer/university

## 9. Alternatives

| Alternative | Credit | Duration | Card Required |
|-------------|--------|----------|---------------|
| Azure Free Account | $200 | 30 days | Yes |
| Azure for Students Starter | None (limited free services only) | 12 months | No |
| GitHub Student Developer Pack | $100 (same Azure for Students offer, not additive) | While student | No |

## 10. Action Plan

1. Verify student eligibility at [azure.microsoft.com/free/students](https://azure.microsoft.com/free/students)
2. Activate subscription with institutional email
3. Set up budget alerts at $25, $50, $75 to monitor credit usage
4. Use free-tier services wherever possible to preserve credit
5. Plan resource cleanup schedule (delete unused resources weekly)
6. Renew annually before expiry

---

## References

- [Azure for Students – Offer Details (MS-AZR-0170P)](https://azure.microsoft.com/en-us/pricing/offers/ms-azr-0170p/)
- [What is Azure for Students? – Microsoft Learn](https://learn.microsoft.com/en-us/azure/education-hub/about-azure-for-students)
- [Azure for Students FAQ](https://learn.microsoft.com/en-us/azure/education-hub/faq)
- [Azure Free Services](https://azure.microsoft.com/en-us/pricing/free-services/)
- [GitHub Student Developer Pack](https://education.github.com/pack)
- [Azure DevOps Pricing](https://azure.microsoft.com/en-us/pricing/details/devops/azure-devops-services/)
- [Azure DevOps Free Tier Documentation](https://github.com/MicrosoftDocs/azure-devops-docs/blob/main/docs/includes/free-tier.md)

*Document created for review purposes. Last verified: 2026-05-26.*
