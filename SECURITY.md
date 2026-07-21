# Security Policy

Glint has no network service or analytics. Report vulnerabilities privately through GitHub's **Report a vulnerability** feature rather than a public issue. Include the affected version, reproduction steps, and impact.

The local event queue can contain project paths and short model-output excerpts. It is stored unencrypted in the current user's Application Support directory. Erase it by quitting Glint and deleting `~/Library/Application Support/Glint`.
