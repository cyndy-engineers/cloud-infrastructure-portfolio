# Cloud & Infrastructure Engineering Portfolio

A static, responsive freelance portfolio with three detailed technical case studies. All links are relative and work on GitHub Pages.

## Preview locally
Open `index.html` in a browser, or run `python -m http.server 8000` from this directory and visit `http://localhost:8000`.

## Case studies
| Case study | Source | Status |
|---|---|---|
| AWS networking + EC2 + S3 | `projects/aws/main.tf` | Terraform authored; live deployment not validated |
| Azure Windows VM + networking + workspace | `projects/azure/main.bicep` | Bicep authored; live deployment not validated |
| Windows event triage | `projects/security/analyze.py` | Runnable offline analyzer with synthetic data and unit tests; Wazuh not deployed |

Each `projects/<name>/README.md` includes execution, validation, evidence and cleanup guidance. **Do not claim that a cloud or Wazuh environment was deployed until you actually test it.**

## Run offline security demo
```bash
cd projects/security
python analyze.py
python -m unittest discover -v
```

## Publish on GitHub Pages
1. Create a new public GitHub repository (e.g. `cloud-infrastructure-portfolio`).
2. In this directory run:
```bash
git init
git add .
git commit -m "Build infrastructure portfolio with technical case studies"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/cloud-infrastructure-portfolio.git
git push -u origin main
```
3. On GitHub, open **Settings → Pages**, select **Deploy from a branch**, **main**, **/(root)** and save.
4. Visit `https://YOUR-USERNAME.github.io/cloud-infrastructure-portfolio/` after deployment.

## Before sharing with Upwork clients
- Replace the example contact email and GitHub link in `index.html`.
- Replace the placeholder brand with your chosen professional name.
- Add only genuine screenshots, test logs, costs and outcomes from your own lab.
- Keep secrets, Terraform state, credentials and private network data out of Git.
- Check Upwork's current rules before including external contact details in portfolio content.

## Notes
Terraform and Bicep code are reference implementations, not production-ready or independently cloud-validated. Cloud resources may incur costs. Security events are synthetic and not real Wazuh output.
