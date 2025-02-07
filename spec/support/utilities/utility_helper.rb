def format_powershell_iis_command(ps_command)
  command = []
  command << 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -noninteractive -noprofile -executionpolicy bypass -command '
  command << '"& {'
  command << 'Import-Module WebAdministration -ErrorAction Stop;'
  command << 'cd iis: ;'
  command << ps_command
  command << '}" < /dev/null'
  command.join
end

def create_selfsigned_cert(dnsname)
  # Due to most self-signed certificate methods don't work on 2008, instead use a test file with a fixed
  # hostname of www.puppet.local.  The helper method will still keep the variable so that when 2008 is dropped
  # only this helper needs to be updated, not the tests.
  raise 'Unable to create a self signed cert for DNS Name of #{dnsname}.  Only www.puppet.local is allowed' unless dnsname == 'www.puppet.local'

  # Test Certificate fixture
  cert_filename_source       = File.dirname(__FILE__) + "/../files/#{dnsname}.pfx"
  cert_filename_dest         = "/cygdrive/c/#{dnsname}.pfx"
  cert_filename_dest_windows = "C:/#{dnsname}.pfx"

  Beaker::DSL::Helpers::HostHelpers.scp_to(default, cert_filename_source, cert_filename_dest)

  # Defaults to personal machine store
  command = format_powershell_iis_command("& CERTUTIL -f -p puppet -importpfx '#{cert_filename_dest_windows}' NoRoot ")
  result = on(default, command)

  # These commands are executed in bash therefore things need to be escaped properly
  command = format_powershell_iis_command("(Get-ChildItem -Path 'Cert:\\LocalMachine\\My' | Where-Object { \\$_.Subject -eq 'CN=#{dnsname}'} | Select-Object -First 1).Thumbprint")
  result = on(default, command)
  result.stdout.chomp
end

def idempotent_apply(work_description, manifest)
  it "#{work_description} runs without errors" do
    execute_manifest(manifest, catch_failures: true)
  end

  it "#{work_description} runs a second time without changes" do
    execute_manifest(manifest, catch_changes: true)
  end
end

def apply_failing_manifest(work_description, manifest)
  it "#{work_description} runs with errors" do
    execute_manifest(manifest, expect_failures: true)
  end
end

def puppet_resource_run(result)
  it 'returns successfully' do
    expect(result.exit_code).to eq 0
  end

  it 'does not return an error' do
    expect(result.stderr).not_to match(%r{\b})
  end
end
