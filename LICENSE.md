### 8G — Add, Commit, and Push

```bash
# Stage all files (add them to the "waiting room" before committing)
git add .

# Commit — this saves a snapshot with a description
git commit -m "Initial commit: staking vault contract with tests"

# Connect your local project to the GitHub repository
git remote add origin https://github.com/yourusername/staking-vault.git

# Push your code to GitHub (main is the default branch name)
git branch -M main
git push -u origin main
