require "capistrano"
require "capistrano/version"

module CapistranoSupervisorResque
  class CapistranoIntegration
    def self.load_into(capistrano_config)
      capistrano_config.load do

        _cset(:supervisor_requires_sudo, false)
        _cset(:supervised_workers, [])
        _cset(:resque_kill_signal, "QUIT")
        _cset(:interval, "5")
        _cset(:supervisorctl_path, "supervisorctl")

        def workers_roles
          return supervised_workers.keys if supervised_workers.first[1].is_a? Hash
          [:resque_worker]
        end

        def for_each_workers(&block)
          if sueprvised_workers.first[1].is_a? Hash
            workers_roles.each do |role|
              yield(role.to_sym, supervised_workers[role.to_sym])
            end
          else
            yield(:resque_worker,supervised_workers)
          end
        end

        def supervisor_command
          "#{(use_sudo || supervisor_requires_sudo) ? "sudo" : ""} #{supervisorctl_path}"
        end

        def supervisor_status_command
          "#{supervisor_command} status"
        end

        def supervisor_pid_command(supervised_worker)
          "cat #{supervisor_command} pid #{supervised_worker}"
        end

        def supervisor_start_command(supervised_worker)
          "#{supervisor_command} start #{supervised_worker}"
        end

        def supervisor_stop_command(supervised_worker)
          "#{supervisor_command} stop #{supervised_worker}"
        end

        namespace :resque do
          desc "See current supervisor status"
          task :status, :roles => lambda { workers_roles() }, :on_no_matching_servers => :continue do
            run(supervisor_status_command)
          end

          desc "Start Resque workers"
          task :start, :roles => lambda { workers_roles() }, :on_no_matching_servers => :continue do
            for_each_workers do |role, workers|
              workers.each do |worker_identifier|
                logger.info "Starting worker #{worker_identifier} with supervisord."
                run(supervisor_start_command(worker_identifier), :roles => role)
              end
            end
          end

          # See https://github.com/defunkt/resque#signals for a descriptions of signals
          # QUIT - Wait for child to finish processing then exit (graceful)
          # TERM / INT - Immediately kill child then exit (stale or stuck)
          # USR1 - Immediately kill child but don't exit (stale or stuck)
          # USR2 - Don't start to process any new jobs (pause)
          # CONT - Start to process new jobs again after a USR2 (resume)
          desc <<-EOS
            Quit running Resque workers

            Instructs supervisord to shutdown all workers. By default (unless it is configured differently) supervisor
            will respond to this instruction by sending a TERM signal to each worker, stopping it immediately.
          EOS
          task :stop, :roles => lambda { workers_roles() }, :on_no_matching_servers => :continue do
            for_each_workers do |role, workers|
              workers.each do |worker_identifier|
                run(supervisor_stop_command(worker_identifier))
              end
            end
          end

          desc <<-EOS
            Restart running Resque workers

            Sends a QUIT signal to each worker process using the pid retrieved from supervisor. This causes workers to gracefully
            shutdown. Supervisord will then restart them for us.
          EOS
          task :restart, :roles => lambda { workers_roles() }, :on_no_matching_servers => :continue do
            for_each_workers do |role, workers|
              workers.each do |worker_identifier|
                run("#{(use_sudo || supervisor_requires_sudo) ? "sudo" : ""} kill -s QUIT `#{supervisor_pid_command(worker_identifier)}`", :roles => role)
              end
            end
          end

          desc "Pauses all workers by sending a USER2 signal."
          task :pause, :roles => lambda { workers_roles() }, :on_no_matching_servers => :continue do
            for_each_workers do |role, workers|
              workers.each do |worker_identifier|
                run("#{(use_sudo || supervisor_requires_sudo) ? "sudo" : ""} kill -s USER2 `#{supervisor_pid_command(worker_identifier)}`", :roles => role)
              end
            end
          end

          desc "Resumes all workers by sending a CONT signal."
          task :pause, :roles => lambda { workers_roles() }, :on_no_matching_servers => :continue do
            for_each_workers do |role, workers|
              workers.each do |worker_identifier|
                run("#{(use_sudo || supervisor_requires_sudo) ? "sudo" : ""} kill -s CONT `#{supervisor_pid_command(worker_identifier)}`", :roles => role)
              end
            end
          end

          namespace :scheduler do
            desc "Starts resque scheduler"
            task :start, :roles => :resque_scheduler do
              if (supervised_scheduler)
                run(supervisor_start_command(supervised_scheduler))
              end
            end

            desc "Stops resque scheduler"
            task :stop, :roles => :resque_scheduler do
              if (supervised_scheduler)
                run(supervisor_stop_command(supervised_scheduler))
              end
            end

            task :restart do
              stop
              start
            end
          end
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  CapistranoSupervisorResque::CapistranoIntegration.load_into(Capistrano::Configuration.instance)
end
