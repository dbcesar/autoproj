require 'erb'
module Autoproj
    module Ops
        # Operations related to building packages
        #
        # Note that these do not perform import or osdeps installation. It is
        # assumed that the packages that should be built have been cleanly
        # imported
        class Build
            # The manifest on which we operate
            # @return [Manifest]
            attr_reader :manifest

            # @param [String] report_dir the log directory in which to build
            #   the build report. If left to nil, no report will be generated
            def initialize(manifest, report_dir: nil)
                @manifest = manifest
                @report_dir = report_dir
            end

            # Triggers a rebuild of all packages
            #
            # It rebuilds (i.e. does a clean + build) of all packages declared
            # in the manifest's layout. It also performs a reinstall of all
            # non-OS-specific managers that support it (e.g. RubyGems) if
            # {update_os_packages?} is set to true (the default)
            def rebuild_all
                packages = manifest.all_layout_packages
                rebuild_packages(packages, packages)
            end

            # Triggers a rebuild of a subset of all packages
            #
            # @param [Array<String>] selected_packages the list of package names
            #   that should be rebuilt
            # @param [Array<String>] all_enabled_packages the list of package names
            #   for which a build should be triggered (usually selected_packages
            #   plus dependencies)
            # @return [void]
            def rebuild_packages(selected_packages, all_enabled_packages)
                selected_packages.each do |pkg_name|
                    Autobuild::Package[pkg_name].prepare_for_rebuild
                end
                build_packages(all_enabled_packages)
            end

            # Triggers a force-build of all packages
            #
            # Unlike a rebuild, a force-build forces the package to go through
            # all build steps (even if they are not needed) but does not clean
            # the current build byproducts beforehand
            #
            def force_build_all
                packages = manifest.all_layout_packages
                rebuild_packages(packages, packages)
            end

            # Triggers a force-build of a subset of all packages
            #
            # Unlike a rebuild, a force-build forces the package to go through
            # all build steps (even if they are not needed) but does not clean
            # the current build byproducts beforehand
            #
            # This method force-builds of all packages declared
            # in the manifest's layout
            #
            # @param [Array<String>] selected_packages the list of package names
            #   that should be rebuilt
            # @param [Array<String>] all_enabled_packages the list of package names
            #   for which a build should be triggered (usually selected_packages
            #   plus dependencies)
            # @return [void]
            def force_build_packages(selected_packages, all_enabled_packages)
                selected_packages.each do |pkg_name|
                    Autobuild::Package[pkg_name].prepare_for_forced_build
                end
                build_packages(all_enabled_packages)
            end


            # Builds the listed packages
            #
            # Only build steps that are actually needed will be performed. See
            # {force_build_packages} and {rebuild_packages} to override this
            #
            # @param [Array<String>] all_enabled_packages the list of package
            #   names of the packages that should be rebuilt
            # @return [void]
            def build_packages(all_enabled_packages, options = Hash.new)
                Autobuild.do_rebuild = false
                Autobuild.do_forced_build = false
                begin
                    Autobuild.apply(all_enabled_packages, "autoproj-build", ['build'], options)
                ensure
                    build_report(all_enabled_packages) if @report_dir
                end
            end

            REPORT_BASENAME = "build_report.json"

            # The path to the report file
            #
            # @return [String,nil] the path, or nil if the report should not
            #    be generated
            def report_path
                File.join(@report_dir, REPORT_BASENAME) if @report_dir
            end

            def build_report(package_list)
                FileUtils.mkdir_p @report_dir

                packages = package_list.map do |pkg_name|
                    pkg = manifest.find_autobuild_package(pkg_name)
                    {
                        name: pkg.name,
                        import_invoked: pkg.import_invoked?,
                        prepare_invoked: pkg.prepare_invoked?,
                        build_invoked: pkg.build_invoked?,
                        failed: pkg.failed?,
                        imported: pkg.imported?,
                        prepared: pkg.prepared?,
                        built: pkg.built?
                    }
                end

                build_report = JSON.pretty_generate({ build_report: { timestamp: Time.now, packages: packages }})
                IO.write(report_path, build_report)
            end
        end
    end
end
