# frozen_string_literal: true

class FinalizeCiBuildNeedsBigIntConversion < Gitlab::Database::Migration[2.1]
  restrict_gitlab_migration gitlab_schema: :gitlab_ci

  TABLE_NAME = 'ci_build_needs'

  def up
    ensure_batched_background_migration_is_finished(
      job_class_name: 'CopyColumnUsingBackgroundMigrationJob',
      table_name: TABLE_NAME,
      column_name: 'id',
      job_arguments: [['id'], ['id_convert_to_bigint']]
    )
  end

  def down; end
end
