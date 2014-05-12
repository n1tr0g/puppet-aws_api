require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_dopts).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(region_name, item, account)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    c = item.configuration
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :region           => region_name,
      :ensure           => :present,
      :tags                 => tags,
      :domain_name          => c[:domain_name],
      :ntp_servers          => c[:ntp_servers],
      :domain_name_servers  => c[:domain_name_servers],
      :netbios_name_servers => c[:netbios_name_servers],
      :netbios_node_type    => c[:netbios_node_type].to_s,
      :account => account
    )
  end
  def self.instances(creds=nil)
    region_list = nil
    creds.collect do |cred|
      keys = cred.reject {|k,v| k == :name}
      region_list ||= regions(keys)
      region_list.collect do |region_name|
        ec2(keys).regions[region_name].dhcp_options.collect { |item| new_from_aws(region_name,item,cred[:name]) }
      end.flatten
    end.flatten
  end
  [:domain_name, :ntp_servers, :netbios_name_servers, :netbios_node_type].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once a dopts set is created."
    end
  end
  def create
    begin
      dopts = ec2.regions[resource[:region]].dhcp_options.create({
        :domain_name          => resource[:domain_name],
        :ntp_servers          => resource[:ntp_servers],
        :domain_name_servers  => resource[:domain_name_servers],
        :netbios_name_servers => resource[:netbios_name_servers],
        :netbios_node_type    => resource[:netbios_node_type]
      })
      tag_with_name dopts, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| dopts.add_tag(k, :value => v) }
      dopts
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

