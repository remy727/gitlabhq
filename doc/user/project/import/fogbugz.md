---
type: reference, howto
stage: Manage
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Import your project from FogBugz to GitLab **(FREE)**

> Ability to re-import projects [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/23905) in GitLab 15.9.

Using the importer, you can import your FogBugz project to GitLab.com
or to your self-managed GitLab instance.

The importer imports all of your cases and comments with the original
case numbers and timestamps. You can also map FogBugz users to GitLab
users.

Prerequisite:

- At least the Maintainer role on the destination group to import to. Using the Developer role for this purpose was
  [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/387891) in GitLab 15.8 and will be removed in GitLab 16.0.

To import your project from FogBugz:

1. Sign in to GitLab.
1. On the top bar, select **New** (**{plus}**).
1. Select **New project/repository**.
1. Select **Import project**.
1. Select **FogBugz**.
1. Enter your FogBugz URL, email address, and password.
1. Create a mapping from FogBugz users to GitLab users.
   ![User Map](img/fogbugz_import_user_map.png)
1. For the projects you want to import, select **Import**.
   ![Import Project](img/fogbugz_import_select_project.png)
1. After the import finishes, select the link to go to the project
   dashboard. Follow the directions to push your existing repository.
1. To import a project:
   - For the first time: Select **Import**.
   - Again: Select **Re-import**. Specify a new name and select **Re-import** again. Re-importing creates a new copy of the source project.
