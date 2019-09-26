local Pipeline(arch) = {
  kind: "pipeline",
  name: arch,
  platform: {
    os: "linux",
    arch: arch
  },
  steps: [
    {
      name: "build",
      image: "plugins/docker",
      environment: {
        GITHUB_TOKEN: {
          from_secret: "GITHUB_TOKEN"
        }
      },
      settings: {
        dry_run: true,
        repo: "dqlite",
        build_args_from_env: [
          "GITHUB_TOKEN",
          "DRONE_BUILD_EVENT",
          "DRONE_REPO_OWNER",
          "DRONE_REPO_NAME",
          "DRONE_COMMIT_REF",
          "DRONE_STAGE_ARCH"
        ]
      }
    }
  ]
};

[
  Pipeline("amd64"),
  Pipeline("arm64"),
  Pipeline("arm"),
]
