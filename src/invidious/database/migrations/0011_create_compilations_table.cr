module Invidious::Database::Migrations
  class CreateCompilationsTable < Migration
    version 8

    def up(conn : DB::Connection)
      if !privacy_type_exists?(conn)
        conn.exec <<-SQL
        CREATE TYPE public.compilation_privacy AS ENUM
        (
          'Unlisted',
          'Private'
        );
        SQL
      end

      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS public.compilations
      (
        title text,
        id text primary key,
        author text,
        description text,
        video_count integer,
        created timestamptz,
        updated timestamptz,
        privacy compilation_privacy,
        index int8[],
        first_video_id text
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON public.compilations TO current_user;
      SQL
    end

    private def privacy_type_exists?(conn : DB::Connection) : Bool
      request = <<-SQL
        SELECT 1 AS one
        FROM pg_type
        INNER JOIN pg_namespace ON pg_namespace.oid = pg_type.typnamespace
        WHERE pg_namespace.nspname = 'public'
          AND pg_type.typname = 'privacy'
        LIMIT 1;
      SQL

      !conn.query_one?(request, as: Int32).nil?
    end
  end
end