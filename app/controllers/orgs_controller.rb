class OrgsController < ApplicationController
  before_action :set_org, only: [:show, :edit, :update, :destroy]

  # GET /orgs
  # GET /orgs.json
  def index
    @orgs = Org.all
  end

  # GET /orgs/1
  # GET /orgs/1.json
  def show
  end

  # GET /orgs/new
  def new
    @org = Org.new
  end

  # GET /orgs/1/edit
  def edit
  end

  # POST /orgs
  # POST /orgs.json
  def create
    @org = Org.new(org_params)

    respond_to do |format|
      if @org.save
        format.html { redirect_to @org, notice: 'Org was successfully created.' }
        format.json { render :show, status: :created, location: @org }
      else
        format.html { render :new }
        format.json { render json: @org.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /orgs/1
  # PATCH/PUT /orgs/1.json
  def update
    respond_to do |format|
      if @org.update(org_params)
        format.html { redirect_to @org, notice: 'Org was successfully updated.' }
        format.json { render :show, status: :ok, location: @org }
      else
        format.html { render :edit }
        format.json { render json: @org.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orgs/1
  # DELETE /orgs/1.json
  def destroy
    @org.destroy
    respond_to do |format|
      format.html { redirect_to orgs_url, notice: 'Org was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def create_new_entry
    logger.debug("the parameters are #{params}")

    dyna_entry = params["catalog"]
    existing_org = Org.find_by_domain(dyna_entry["url"])

    if existing_org.nil?
      org = Org.new
    else
      logger.debug("****** THE ORG EXISTS")
      org = existing_org

    end
    org.name = dyna_entry["OrganizationName"]["OrganizationName"][0]["Text"] if dyna_entry["OrganizationName"]["OrganizationName"][0]["Text"]
    org.domain = dyna_entry["url"]
    org.description_display = dyna_entry["OrganizationName"]["OrganizationDescriptionDisplay"] if dyna_entry["OrganizationName"]["OrganizationDescriptionDisplay"]
    org.org_type = dyna_entry["OrganizationName"]["Type"] if dyna_entry["OrganizationName"]["Type"]
    org.home_url = dyna_entry["OrganizationName"]["HomePageURL"] if dyna_entry["OrganizationName"]["HomePageURL"]
    org.inactive = dyna_entry["OrganizationName"]["InactiveCatalog"] if dyna_entry["OrganizationName"]["InactiveCatalog"]
    if org.save
      grabbed_org_desc = dyna_entry["OrganizationName"]["OrgDescription"]

      if grabbed_org_desc
        grabbed_org_desc.each do |god|
          if !god.empty?
            GrabList.create(field_name: "OrganizationDescription", text: god["Text"], xpath: god["Xpath"],
                            page_url: god["Domain"], org: org)
          end
        end
      end

      grabbed_org_name = dyna_entry["OrganizationName"]["OrganizationName"][0]
      if !grabbed_org_name.empty?
        GrabList.create(field_name: "OrganizationName", text: grabbed_org_name["Text"], xpath: grabbed_org_name["Xpath"],
                        page_url: grabbed_org_name["Domain"], org: org)
      end

      #Code to extract sites data into postgrace
      if dyna_entry["OrgSites"]
        dyna_entry["OrgSites"].each do |site|
          extract_site_data(site, org)
        end
      end

      #Code to extract program data into postgrace
      if dyna_entry["Programs"]
        dyna_entry["Programs"].each do |p|
          extract_programs_data(p,org, dyna_entry)
        end
      end

      if dyna_entry["GeoScope"]
        extract_geo_scope_data(dyna_entry["GeoScope"], org)
      end

    end

  end


  def update_sites
    dyna_entry = params["catalog"]
    org = Org.find_by_domain(dyna_entry["url"])
    sites = dyna_entry["sites"]

    sites.each do |site|
      existing_site = Site.where(["org_id = ? and site_name = ?", org.id, site["LocationName"]])
      if existing_site.empty?
        s = Site.new
      else
        s = existing_site.first
      end
      s.site_name = site["LocationName"] if site["LocationName"]
      s.site_url = site["Webpage"] if site["Webpage"]
      s.site_ref = site["Referrals"] if site["Referrals"]
      s.admin = site["AdminSite"] if site["AdminSite"]
      s.delivery = site["ServiceDeliverySite"] if site["ServiceDeliverySite"]
      s.resource_dir = site["ResourceDirectory"] if site["ResourceDirectory"]
      s.inactive = site["InactiveSite"] if site["InactiveSite"]
      s.org_id = org.id
      if s.save
        create_location(s, site)
        create_poc(s,site,org)
      else
        logger.debug("******the error in s save is : #{s.errors.full_messages}")
      end
    end






  end


  def update_programs

    dyna_entry = params["catalog"]
    org = Org.find_by_domain(dyna_entry["url"])
    programs = dyna_entry["programs"]

    programs.each do |p|
      logger.debug("the program is : #{p}--------- org is #{org.id} ")

      program_check = Program.where(["org_id = ? and name = ?", org.id, p["ProgramName"]])

      if program_check.nil?
        prgm = Program.new
      else
        prgm = program_check.first
      end

      prgm.name = p["ProgramName"] if p["ProgramName"]
      prgm.quick_url = p["QuickConnectWebPage"] if p["QuickConnectWebPage"]
      prgm.contact_url = p["ContactWebPage"] if p["ContactWebPage"]
      prgm.program_url = p["ProgramWebPage"] if p["ProgramWebPage"]
      prgm.program_description_display = p["ProgramDescriptionDisplay"] if p["ProgramDescriptionDisplay"]
      prgm.population_description_display = p["PopulationDescriptionDisplay"] if p["PopulationDescriptionDisplay"]
      prgm.service_area_description_display = p["ServiceAreaDescriptionDisplay"] if p["ServiceAreaDescriptionDisplay"]
      prgm.inactive = p["InactiveProgram"] if p["InactiveProgram"]
      prgm.org_id = org.id
      if prgm.save
        attached_sites = p["ProgramSites"]
        program_sites = ProgramSite.where(program_id: prgm.id)
        program_sites.each do |ps|
          ps.destroy
        end
        if p.key?("ProgramSites")
          attached_sites.each do |site|
            entry = dyna_entry["dyna_entry"]["OrgSites"].select{|o| o["SelectSiteID"] == site}
            logger.debug("the selected entry is : #{entry}, site id is : #{site}")
            name = entry[0].nil? ? "" : entry[0]["LocationName"]
            logger.debug("@@@@@@@@@@@@@@@@@ the name of the location is : #{name}")
            if !name.blank?
              s = Site.where(["org_id = ? and site_name = ?", org.id, name]).first
              logger.debug(".>>>>>>>>>>**************the sete you are looking for is : #{s}")
              ps = ProgramSite.new
              ps.site =  s
              ps.program = prgm
              if ps.save
              else
                logger.debug("ps is not saving because : #{ps.errors.full_messages}")
              end
            end
          end
        end
      end

      create_groups(p, prgm, org)
      service_tags = p["ServiceTags"].split(", ")
      service_tag_list = ServiceTag.all.pluck("name")
      service_tags.each do|st|
        if !service_tag_list.include? (st)
          ServiceTag.create(name: st)
        end
        selected_tag = ServiceTag.find_by_name(st)
        if ProgramServiceTag.where(["program_id = ? and service_tag_id = ?", prgm.id, selected_tag.id]).empty?
          ProgramServiceTag.create(org: org, program: prgm, service_tag: selected_tag)
        end
      end

      p.each do |key,value|
        if ["ProgramDescription", "PopulationDescription", "ServiceAreaDescription" ].include? (key)

          value.each do |grabbed_field|
            if GrabList.where(["field_name = ? and program_id = ?", key, prgm.id]).empty?

                GrabList.create(field_name: key , text: grabbed_field["Text"], xpath: grabbed_field["Xpath"],
                                page_url: grabbed_field["Domain"], org: org, program_id: prgm.id)
            else
              GrabList.where(["field_name = ? and program_id = ?", key, prgm.id]).first.update(field_name: key ,
                                                                                               text: grabbed_field["Text"],
                                                                                               xpath: grabbed_field["Xpath"],
                                                                                               page_url: grabbed_field["Domain"],
                                                                                               org: org, program_id: prgm.id)
            end
          end
        end
      end
    end



  end

  def extract_geo_scope_data(data, org)
    existing_scope = org.scopes
    if existing_scope.empty?
      scope = Scope.new
    else
      logger.debug("***********the SCOPE ALREADY EXISTS***************")
      scope = existing_scope.first  
    end
    scope.geo_scope = data["Scope"] if data["Scope"]
    scope.neighborhood = data["Neighborhoods"] if data["Neighborhoods"]
    scope.service_area_name = data["ServiceAreaName"] if data["ServiceAreaName"]
    scope.city = data["City"] if data["City"]
    scope.county = data["County"] if data["County"]
    scope.state = data["State"] if data["State"]
    scope.region = data["Region"] if data["Region"]
    scope.country = data["Country"] if data["Country"]
    scope.inactive = data["InactiveCatalog"] if data["InactiveCatalog"]
    scope.org_id = org.id
    scope.save
  end

  def create_groups(p, prgm,org)
    all_servicegroup_list = ServiceGroup.all.pluck("name")
    all_popgroup_list = PopulationGroup.all.pluck("name")
    ProgramServiceGroup.where(program_id: prgm.id).each do |psg|
      psg.destroy
    end

    ProgramPopulationGroup.where(program_id: prgm.id).each do |ppg|
      ppg.destroy
    end

    p.each do |key,value|
        if key[0..1] == "S_"
          name = key.split("_")[1]
          if !all_servicegroup_list.include? (name)
            sg = ServiceGroup.create(name: name)
          end
          if value == true
            selected_sg = ServiceGroup.find_by_name(name)
            ProgramServiceGroup.create(org: org, program: prgm, service_group: selected_sg)
          end
        elsif key[0..1] == "P_"
          name = key.split("_")[1]
          if !all_popgroup_list.include? (name)
            pg = PopulationGroup.create(name: name)
          end
          if value == true
            selected_pg = PopulationGroup.find_by_name(name)
            ProgramPopulationGroup.create(org: org, program: prgm, population_group: selected_pg)
          end
        end
    end
  end

  def extract_programs_data(p,org, dyna_entry)

    existing_prgm = Program.where(["org_id = ? and name = ?", org.id, p["ProgramName"]])

    if existing_prgm.empty?
      prgm = Program.new
    else
      prgm = existing_prgm.first
    end

    prgm.name = p["ProgramName"] if p["ProgramName"]
    prgm.quick_url = p["QuickConnectWebPage"] if p["QuickConnectWebPage"]
    prgm.contact_url = p["ContactWebPage"] if p["ContactWebPage"]
    prgm.program_url = p["ProgramWebPage"] if p["ProgramWebPage"]
    prgm.program_description_display = p["ProgramDescriptionDisplay"] if p["ProgramDescriptionDisplay"]
    prgm.population_description_display = p["PopulationDescriptionDisplay"] if p["PopulationDescriptionDisplay"]
    prgm.service_area_description_display = p["ServiceAreaDescriptionDisplay"] if p["ServiceAreaDescriptionDisplay"]
    prgm.inactive = p["InactiveProgram"] if p["InactiveProgram"]
    prgm.attached_sites = p["ProgramSites"] if p["ProgramSites"]
    prgm.org_id = org.id
    if prgm.save
      attached_sites = p["ProgramSites"]
      program_sites = ProgramSite.where(program_id: prgm.id)
      program_sites.each do |ps|
        ps.destroy
      end
      if p.key?("ProgramSites")
        attached_sites.each do |site|
          entry = dyna_entry["OrgSites"].select{|o| o["SelectSiteID"] == site}
          logger.debug("the selected entry is : #{entry}, site id is : #{site}")
          name = entry[0].nil? ? "" : entry[0]["LocationName"]
          logger.debug("@@@@@@@@@@@@@@@@@ the name of the location is : #{name}")
          if !name.blank?
            s = Site.where(["org_id = ? and site_name = ?", org.id, name]).first
            logger.debug(".>>>>>>>>>>**************the sete you are looking for is : #{s}")
            ps = ProgramSite.new
            ps.site =  s
            ps.program = prgm
            if ps.save
            else
              logger.debug("ps is not saving because : #{ps.errors.full_messages}")
            end
          end
        end
      end

      create_groups(p, prgm, org)
      service_tags = p["ServiceTags"].split(", ")
      service_tag_list = ServiceTag.all.pluck("name")
      service_tags.each do|st|
        if !service_tag_list.include? (st)
          ServiceTag.create(name: st)
        end
        selected_tag = ServiceTag.find_by_name(st)
        if ProgramServiceTag.where(["program_id = ? and service_tag_id = ?", prgm.id, selected_tag.id]).empty?
          ProgramServiceTag.create(org: org, program: prgm, service_tag: selected_tag)
        end
      end


      p.each do |key,value|
        if ["ProgramDescription", "PopulationDescription", "ServiceAreaDescription" ].include? (key)

          value.each do |grabbed_field|
            if GrabList.where(["field_name = ? and program_id = ?", key, prgm.id]).empty?

              GrabList.create(field_name: key , text: grabbed_field["Text"], xpath: grabbed_field["Xpath"],
                              page_url: grabbed_field["Domain"], org: org, program_id: prgm.id)
            else
              GrabList.where(["field_name = ? and program_id = ?", key, prgm.id]).first.update(field_name: key ,
                                                                                               text: grabbed_field["Text"],
                                                                                               xpath: grabbed_field["Xpath"],
                                                                                               page_url: grabbed_field["Domain"],
                                                                                               org: org, program_id: prgm.id)
            end
          end
        end
      end
      # value.each do |grabbed_field|
      #   GrabList.create(field_name: key , text: grabbed_field["Text"], xpath: grabbed_field["Xpath"],
      #                   page_url: grabbed_field["Domain"], org: org, program_id: prgm.id)
      # end

    end
  end

  def extract_site_data(site, org)

    existing_site = Site.where(["org_id = ? and site_name = ?", org.id, site["LocationName"]])
    if existing_site.empty?
      s = Site.new
    else
      s = existing_site.first
    end
    s.site_name = site["LocationName"] if site["LocationName"]
    s.name = site["Name"] if site["Name"]
    s.site_url = site["Webpage"] if site["Webpage"]
    s.site_ref = site["Referrals"] if site["Referrals"]
    s.admin = site["AdminSite"] if site["AdminSite"]
    s.delivery = site["ServiceDeliverySite"] if site["ServiceDeliverySite"]
    s.resource_dir = site["ResourceDirectory"] if site["ResourceDirectory"]
    s.inactive = site["InactiveSite"] if site["InactiveSite"]
    s.select_site_id = site["SelectSiteID"] if site["SelectSiteID"]
    s.org_id = org.id
    if s.save
      logger.debug("******* SITE IS SAVED******")
      create_location(s, site)
      create_poc(s,site,org)
    else
      logger.debug("******the error in s save is : #{s.errors.full_messages}")
    end


  end

  def create_location(s, site)
    logger.debug("**********the site in create location is : #{s.inspect}")
    if !site.key?("Addr1").nil? && !site["AddrCity"].nil?
      existing_loc = Location.where("sites_id = ? and addr1 = ?", s.id, site["Addr1"][0]["Text"])
      logger.debug("*888888********the existing loc is : #{existing_loc.inspect}")
      if existing_loc.empty?
        loc = Location.new
      else
        loc = existing_loc.first
      end
      logger.debug("**********the site in create locationnnnn 2222222 is : #{s.inspect}")
      loc.addr1 = site.key?("Addr1") ? site["Addr1"][0]["Text"] : ""
      loc.city = site["AddrCity"] if site["AddrCity"]
      loc.state = site["AddrState"] if site["AddrState"]
      loc.zip = site["AddrZip"] if site["AddrZip"]
      loc.phone = site["OfficePhone"] if site["OfficePhone"]
      loc.email = site["Email"] if site["Email"]
      loc.primary_poc = site["DefaultPOC"] if site["DefaultPOC"]
      loc.inactive = site["InactiveSite"] if site["InactiveSite"]
      loc.sites_id = s.id
      if loc.save
      else
        logger.debug("---------------******the reasson why loc is not saving is #{loc.errors.full_messages}")
      end
    end

  end

  def create_poc(s,site,org)

    SitePoc.where(site_id: s.id).each do |sp|
      sp.destroy
    end
    if site.key?("POCs")
      site["POCs"].each do |contact|
        existing_poc = Poc.where(["org_id = ? and poc_name = ?", org.id, contact["poc"]["Name"]])
        if existing_poc.empty?
          poc = Poc.new
        else
          poc = existing_poc.first
        end
        poc.org = org
        poc.poc_name = contact["poc"]["Name"]
        poc.title = contact["poc"]["Title"]
        poc.work = contact["poc"]["OfficePhone"]
        poc.email = contact["poc"]["Email"]
        poc.inactive = contact["poc"]["InactivePOC"]
        if poc.save
          SitePoc.create(poc: poc, site: s)
        end
      end
    end
    
  end



  def catalog_search

    #--- {'population': {'conditional': 'OR', 'value': ['P_Citizenship']},
    #---  'services': {'type': 'group', 'conditional': 'OR', 'value': ['S_Clothing']},
    #---+++  'name': 'YWCA Kitsap County',
    #---+++  'tags': ['Repair'],
    #---  'GeoScope': {'value': 'WA', 'type': 'State'},
    #  'application_name': 'demo'}
    # {'GeoScope': {'value': 'National', 'type': 'Scope'}, 'application_name': 'demo'}

    query_params = params["search_params"].keys
    all_acttive_programs = Program.where(inactive: nil)
    logger.debug("query_params iss : #{query_params}")
    if query_params.sort == ["application_name"].sort
      logger.debug("ONLY application")
      all_programs = all_acttive_programs

    elsif query_params.sort == ["tags","application_name"].sort
      logger.debug("*********IN THE TAGS")
      # tags = params["search_params"]["tags"]
      tags = params["search_params"]["tags"].collect(&:strip)
      all_programs = filter_tags(tags,all_acttive_programs)
      #all_programs = Program.joins(:service_tags).where(service_tags: {name: tags}, inactive: nil)

    elsif query_params.sort == ["population","application_name"].sort
      logger.debug("*********IN the population")
      population_groups = split_values(params["search_params"]["population"]["value"])
      all_programs = Program.joins(:population_groups).where(population_groups: {name: population_groups}, inactive: nil)
      # all_programs = filter_population_groups(population_groups, all_acttive_programs)

    elsif query_params.sort == ["services","application_name"].sort
      logger.debug('***************IN THE SERVICES')
      service_groups = split_values(params["search_params"]["services"]["value"])
      # all_programs = Program.joins(:service_groups).where(service_groups: {name: service_groups}, inactive: nil)
      all_programs = filter_service_groups(service_groups,all_acttive_programs)

    elsif query_params.sort == ['name','application_name'].sort
      logger.debug("********IN THE NAME")
      org_name = params["search_params"]["name"]
      # all_org = Org.where("name ILike ?", "%" + org_name + "%")

      all_programs = filter_name(org_name,all_acttive_programs)

    elsif query_params.sort == ["GeoScope","application_name"].sort

      scope_value = params["search_params"]["GeoScope"]["value"]
      scope_type = params["search_params"]["GeoScope"]["type"]
      all_programs = filter_scope(scope_value, scope_type,all_acttive_programs)

    else
      logger.debug("************IN the final else")
      programs = all_acttive_programs
      if query_params.include? ('name')
        logger.debug("************IN the final else------------NAME")
        org_name = params["search_params"]["name"]
        programs = filter_name(org_name,programs)
      end
      if query_params.include? ('services')
        logger.debug("************IN the final else-----------SERVICES")
        service_groups = split_values(params["search_params"]["services"]["value"])
        programs = filter_service_groups(service_groups,programs)
      end
      if query_params.include? ('population')
        logger.debug("************IN the final else-----------POPULATION")
        population_groups = split_values(params["search_params"]["population"]["value"])
        #programs = programs.joins(:population_groups).where(population_groups: {name: population_groups})
        programs = filter_population_groups(population_groups, programs)
      end
      if query_params.include? ('tags')
        logger.debug("************IN the final else-------------TAGS---#{programs.count}")
        # tags = params["search_params"]["tags"]
        tags = params["search_params"]["tags"].collect(&:strip)
        programs = filter_tags(tags,programs)
        # programs = programs.joins(:service_tags).where(service_tags: {name: tags})
      end
      if query_params.include? ('GeoScope')
        scope_value = params["search_params"]["GeoScope"]["value"]
        scope_type = params["search_params"]["GeoScope"]["type"]
        programs = filter_scope(scope_value, scope_type, programs)
      end

      all_programs = programs

    end

    provider_list = split_programs(all_programs)
    complete_result = create_complete_hash(all_programs)

    render :json => {status: :ok,count: provider_list.count, provider_list: provider_list, complete_result: complete_result }

  end


  def create_complete_hash(programs)


    provider_list = []
    programs.each do |p|
      org = p.org
      scope = org.scopes.first
      org_name_grab_field = org.grab_lists.where(field_name: "OrganizationName").first
      program_services = p.service_groups.pluck(:name)
      program_population = p.population_groups.pluck(:name)
      p_service_tags = p.service_tags.pluck(:name).join(", ")
      p_sites = p.sites
      program_sites_array = [ ]

      p_sites.each do |ps|
        # pocs = ps.pocs
        location = Location.where(sites_id: ps.id).first

        if !location.nil?
          site = {
              "Addr1": [
                  {
                      "Domain": "n/a",
                      "Text": location.addr1,
                      "Xpath": "n/a"
                  }
              ],
              "AddrCity": location.city,
              "AddrState": location.state,
              "AddrZip": location.zip,
              # "AdminSite": true,
              # "DefaultPOC": false,
              "Email": location.email,
              # "InactivePOC": false,
              "InactiveSite": ps.inactive.nil? ? false : ps.inactive ,
              "LocationName": ps.site_name,
              "Name": ps.name,
              "OfficePhone": location.phone,
              "POCs": [
                  {
                      "id": "1.0",
                      "poc": {
                          # "DefaultPOC": false,
                          "Email": location.email,
                          # "InactivePOC": false,
                          "Name": ps.name,
                          "OfficePhone": location.phone
                      }
                  }
              ],
              # "ResourceDirectory": false,
              "SelectSiteID": ps.select_site_id
              # "ServiceDeliverySite": true
          }

          program_sites_array.push(site)
        end


      end

      # prog_name = p.name
      # org_name = org.name
      # org_domain = org.domain
      # provider = {domain: org_domain ,org_name: org_name, prog_name: prog_name}
      # provider_list.push(provider)


      provider = {
        "GeoScope": {
            "City": scope.city,
            "Country": scope.country,
            "County": scope.county,
            "Neighborhoods": scope.neighborhood,
            "Region": scope.region,
            "Scope": scope.geo_scope,
            "ServiceAreaName": scope.service_area_name,
            "State": scope.state
        },
        # "missing_mandatory_fields": "0",
        "OrganizationName": {
            "HomePageURL": org.home_url,
            "InactiveCatalog": org.inactive,

            "OrganizationDescriptionDisplay": org.description_display.nil? ? "n/a" : org.description_display,

            "OrganizationName": [
                {
                    "Domain": org_name_grab_field.page_url.nil? ? "n/a" : org_name_grab_field.page_url ,
                    "Text": org_name_grab_field.text,
                    "Xpath": org_name_grab_field.xpath.nil? ? "n/a" : org_name_grab_field.xpath
                }
            ],
            "OrgDescription": [
                {
                    # "Domain": "https://arcwa.org/",
                    "Text": org.description_display.nil? ? "n/a" : org.description_display
                    # "Xpath": "span"
                }
            ],
            "Type": org.org_type
        },
        "OrgSites": program_sites_array ,
        "poc_emailed": true,
        "Programs": {
                "ContactWebPage": p.contact_url,
                "InactiveProgram": p.inactive.nil? ? false : p.inactive,
                "P_Any": program_population.include?("Any") ? true : false,
                "P_Citizenship": program_population.include?("Citizenship") ? true : false,
                "P_Disabled": program_population.include?("Disabled") ? true : false,
                "P_Family": program_population.include?("Family") ? true : false,
                "P_LGBTQ": program_population.include?("LGBTQ") ? true : false,
                "P_LowIncome": program_population.include?("LowIncome") ? true : false,
                "P_Native": program_population.include?("Native") ? true : false,
                "P_Other": program_population.include?("Other") ? true : false,
                "P_Senior": program_population.include?("Senior") ? true : false,
                "P_Veteran": program_population.include?("Veteran") ? true : false,
                "PopulationDescription": [
                    {

                    }
                ],
                "ProgramDescriptionDisplay": p.program_description_display,
                "ProgramName": p.name,
                "ProgramSites": p.attached_sites,
                "ProgramWebPage": p.program_url ,
                "QuickConnectWebPage": p.quick_url,
                "S_Abuse": program_services.include?("Abuse") ? true : false,
                "S_Addiction": program_services.include?("Addiction") ? true : false,
                "S_BasicNeeds": program_services.include?("BasicNeeds") ? true : false,
                "S_Behavioral": program_services.include?("Behavioral") ? true : false,
                "S_CaseManagement": program_services.include?("CaseManagement") ? true : false,
                "S_Clothing": program_services.include?("Clothing") ? true : false,
                "S_COVID19": program_services.include?("COVID19") ? true : false,
                "S_DayCare": program_services.include?("DayCare") ? true : false,
                "S_Dental": program_services.include?("Dental") ? true : false,
                "S_Disabled": program_services.include?("Disabled") ? true : false,
                "S_Education": program_services.include?("Education") ? true : false,
                "S_Emergency": program_services.include?("Emergency") ? true : false,
                "S_Employment": program_services.include?("Employment") ? true : false,
                "S_Family": program_services.include?("Family") ? true : false,
                "S_Financial": program_services.include?("Financial") ? true : false,
                "S_Food": program_services.include?("Food") ? true : false,
                "S_GeneralSupport": program_services.include?("GeneralSupport") ? true : false,
                "S_Housing": program_services.include?("Housing") ? true : false,
                "S_Identification": program_services.include?("Identification") ? true : false,
                "S_IndependentLiving": program_services.include?("IndependentLiving") ? true : false,
                "S_Legal": program_services.include?("Legal") ? true : false,
                "S_Lists & Guides": program_services.include?("Lists & Guides") ? true : false,
                "S_Medical": program_services.include?("Medical") ? true : false,
                "S_Research": program_services.include?("Research") ? true : false,
                "S_Resources": program_services.include?("Resources") ? true : false,
                "S_Respite": program_services.include?("Respite") ? true : false,
                "S_Senior": program_services.include?("Senior") ? true : false,
                "S_Transportation": program_services.include?("Transportation") ? true : false,
                "S_Veterans": program_services.include?("Veterans") ? true : false,
                "S_Victim": program_services.include?("Victim") ? true : false,
                "S_Vision": program_services.include?("Vision") ? true : false,
                "SelectprogramID": "1",
                "ServiceAreaDescription": [
                    {

                    }
                ],
                "ServiceAreaDescriptionDisplay": p.service_area_description_display,
                "ServiceTags": p_service_tags
            },
        "status": "Approved",
        "url": org.domain,
        "id": p.id
    }

      provider_list.push(provider)
    end
    provider_list



  end




  def split_values(query_array)
    new_array = []
    query_array.each do |qa|
      new_array.push(qa.split("_")[1])
    end

    new_array
  end

  #---  'GeoScope': {'value': 'WA', 'type': 'State'},
  # {'GeoScope': {'value': 'National', 'type': 'Scope'}, 'application_name': 'demo'}
  def filter_scope(scope_value, scope_type, programs)
    programs_array = []

    programs.each do |p|
      if !p.org.inactive?
        prog_scope_type = p.org.scopes.first.geo_scope
        if scope_type == "State"
          prog_scope_value = p.org.scopes.first.state

        elsif scope_type == "County"
          prog_scope_value = p.org.scopes.first.county

        elsif scope_type == "City"
          prog_scope_value = p.org.scopes.first.city

        elsif scope_type == "Scope"


        end

        if ['National', 'Virtual'].include? (scope_value)

          if prog_scope_type.downcase == scope_value.downcase
            programs_array.push(p)
          end

        else
          if (prog_scope_type == scope_type) && (prog_scope_value.downcase.include? (scope_value.downcase))
            logger.debug("THE the value of the prog_scope_value: #{prog_scope_value} :: #{prog_scope_value}-------type : #{prog_scope_type} :: #{scope_type} ")
            programs_array.push(p)
          end
        end

      end
    end

    programs_array

  end

  def filter_population_groups(population_groups,programs)
    population_group_count = population_groups.count
    programs_array = []

    programs.each do |p|
      if !p.org.inactive?
        true_array = []
        population_groups.each do |pg|
          if !p.population_groups.where(name: pg).blank?
            true_array.push("true")
          end
        end
        if true_array.count == population_group_count
          programs_array.push(p)
        end
      end
    end

    programs_array
    # Program.joins(:population_groups).where(population_groups: {name: population_groups})
  end

  def split_programs(programs)
    provider_list = []
    programs.each do |p|
      org = p.org
      prog_name = p.name
      org_name = org.name
      org_domain = org.domain
      provider = {domain: org_domain ,org_name: org_name, prog_name: prog_name}
      provider_list.push(provider)

    end
    provider_list

  end

  def filter_name(name,program)
    programs_array = []
    #logger.debug("**********IN the filter name #{name}")

    program.each do |p|

      if !p.org.inactive?
        if p.org.name.downcase.include?(name.downcase)
          #logger.debug("****The name is a match #{p.org.name}")
          programs_array.push(p)
        end
      end
    end

    programs_array
    # Org.where("name ILike ?", "%" + name + "%")
  end

  def filter_prog_desc(prog_description,program)
    programs_array = []
    #logger.debug("**********IN the filter name #{name}")

    program.each do |p|

      if !p.org.inactive?
        if !p.program_description_display.nil?
          if p.program_description_display.downcase.include?(prog_description.downcase)
            #logger.debug("****The name is a match #{p.org.name}")
            programs_array.push(p)
          end
        end
      end
    end

    programs_array
    # Org.where("name ILike ?", "%" + name + "%")
  end

  def filter_tags(tags,programs)
    tags_count = tags.count
    programs_array = []

    programs.each do |p|
      if !p.org.inactive?
        true_array = []
        tags.each do |t|
          if !p.service_tags.where("name ILike ?", "%" + t + "%").blank?
            # true_array.push("true")
            programs_array.push(p)
            break
          end
        end
        # if true_array.count == tags_count
        #   # programs_array.push(p)
        # end
      end
    end

    programs_array
    # Program.joins(:service_tags).where(service_tags: {name: tags})
  end


  def filter_service_groups(service_groups,programs)
    service_groups_count = service_groups.count
    programs_array = []

    programs.each do |p|
      if !p.org.inactive?
        true_array = []
        service_groups.each do |sg|
          if !p.service_groups.where(name: sg).blank?
            true_array.push("true")
          end
        end
        if true_array.count == service_groups_count
          programs_array.push(p)
        end
      end
    end

    programs_array
    # Program.joins(:service_groups).where(service_groups: {name: service_groups})
  end


  def advanced_search
    #PopulationContainer: [{Value: “care”, modifier: “False”, connector: “AND|OR”},
    # {Value: “Citizenship”, modifier: “False”, connector: “AND|OR”}]
    f_query = FavoriteQuery.new
    f_query.query_name = params["query_name"]
    f_query.owner = params[:email] if params[:email]
    f_query.query_count = 1
    f_query.global = params["global_query"]
    f_query.search_query = params["search_params"]
    f_query.save

    query_params = params["search_params"].keys

    service_group_result = []
    population_group_result = []
    service_tag_result = []
    org_name_result = []
    prog_description_result = []
    geo_scope_result = []
    search_category_result_array = []
    final_program_array = []


    # logger.debug("query_params iss : #{query_params.empty?}")
    # service_groups = split_values(params["search_params"]["services"]["value"])
    # if query_params.sort == ["ServiceGroupsContainer"].sort
    if query_params.empty?
      # logger.debug("**************you are in the epmty")
      all_active_programs = Program.where(inactive: nil)
      final_program_array = all_active_programs
      # logger.debug("**********active programs are #{final_program_array.count}")
    else
      if query_params.include?("ServiceGroupsContainer")
        program_name_array = []

        service_group_container = params["search_params"]["ServiceGroupsContainer"]
        service_group_container.each do |s|
          service_group = ServiceGroup.find_by_name(s["value"])
          service_programs = service_group.programs.pluck(:name)
          program_name_array = create_program_names_array(program_name_array, s, service_programs)
        end

        # logger.debug("*************the program name array for service group is : #{program_name_array}")

        service_group_result = fdsdkfe(program_name_array, service_group_container )
        search_category_result_array.push(service_group_result)
        # logger.debug("*********** THE FINAL RESULT IN service_group_container IS: {service_group_result} ")
      end

      if query_params.include?("PopGroupContainer")
        program_name_array = []

        population_group_container = params["search_params"]["PopGroupContainer"]
        population_group_container.each do |s|
          population_group_programs=  PopulationGroup.find_by_name(s["value"]).programs.pluck(:name)
          program_name_array = create_program_names_array(program_name_array, s, population_group_programs)
        end
        population_group_result = fdsdkfe(program_name_array, population_group_container )

        search_category_result_array.push(population_group_result )
        # logger.debug("*********** THE FINAL RESULT IN population_group_container IS: {population_group_result} ")

      # elsif query_params.sort == ["ServiceTagsContainer"].sort
      end

      if query_params.include?("ServiceTagsContainer")

        program_name_array = []

        service_tag_container = params["search_params"]["ServiceTagsContainer"]
        service_tag_container.each do |s|
          service_tag_programs =  ServiceTag.find_by_name(s["value"]).programs.pluck(:name)
          program_name_array = create_program_names_array(program_name_array, s, service_tag_programs)
        end
        service_tag_result = fdsdkfe(program_name_array, service_tag_container )

        search_category_result_array.push(service_tag_result)
        # logger.debug("*********** THE FINAL RESULT IN service_tag_container IS: #{service_tag_result} ")
      end

      if query_params.include? ('name')
        all_acttive_programs = Program.where(inactive: nil)
        # logger.debug("************IN the final else------------NAME")
        org_name = params["search_params"]["name"]
        programs = filter_name(org_name,all_acttive_programs)
        org_name_result = programs.pluck(:name)

        search_category_result_array.push(org_name_result)

        # logger.debug("*********** THE FINAL RESULT IN NAME IS: #{org_name_result} ")
      end

      if query_params.include? ('ProgDescr')

        all_acttive_programs = Program.where(inactive: nil)
        # logger.debug("************IN the final else------------NAME")
        prog_description = params["search_params"]["ProgDescr"]
        programs = filter_prog_desc(prog_description,all_acttive_programs)
        prog_description_result = programs.pluck(:name)

        search_category_result_array.push(prog_description_result)
        # logger.debug("*********** THE FINAL RESULT IN PROGRAM DESCRIPTION IS: #{prog_description_result} ")

      end

      if query_params.include? ('GeoScope')
        scope_value = params["search_params"]["GeoScope"]["value"]
        scope_type = params["search_params"]["GeoScope"]["type"]
        all_active_programs = Program.where(inactive: nil)
        programs = filter_scope(scope_value, scope_type, all_active_programs)
        geo_scope_result = programs.pluck(:name)

        search_category_result_array.push(geo_scope_result)
      end

      # logger.debug("*************** the  search_category_result_array #{search_category_result_array}")
      final_program_names = []
      search_category_result_array.each_with_index do |scra, i |
        # logger.debug("*************** the lenght of search_category_result_array #{search_category_result_array.length}")
        if search_category_result_array.length == 1
          final_program_names = scra
        else
          # logger.debug("*************** the value of I is #{i}")
          if i == 1
            final_program_names = search_category_result_array[0] & search_category_result_array[1]
          else
            final_program_names = final_program_names & search_category_result_array[i]
          end
        end

      end

      # logger.debug("service_group_result: #{service_group_result.count}, population_group_result: #{population_group_result.count},
      #            service_tag_result: #{service_tag_result.count}, org_name_result: #{org_name_result.count}, prog_description_result: #{prog_description_result.count}  ")
      # final_program_names = (service_group_result + population_group_result + service_tag_result + org_name_result +
      #     prog_description_result + geo_scope_result ).uniq

      # logger.debug("************ the final program names are --- #{final_program_names}")
      final_program_array = []
      final_program_names.each do |pn|
        program = Program.find_by_name(pn)
        if program.inactive != true
          final_program_array.push(program)
        end
      end
    end

    complete_result = create_complete_hash(final_program_array)

    render :json => {status: :ok, result_count: complete_result.count , complete_result: complete_result }

  end

  def create_program_names_array(program_name_array, s, program_names)
    if s["modifier"] == "False"
      program_name_array.push(program_names)

    else
      all_programs = Program.all.pluck(:name)
      prog = all_programs - program_names
      program_name_array.push(prog)
    end
    program_name_array
  end

  def fdsdkfe(program_name_array, p )

    r = []
    p.each_with_index do |ser, i |
      # puts("*********** THE VALUE OF I IS : #{i} ----- ")

      if p.length == 1
        r = program_name_array[0]
      else
        next if i == 0
        if ser[:connector] == "AND"
          if i == 1
            r = program_name_array[0] & program_name_array[1]
          else
            # puts("********* THE VALUE ID R in and IS : #{r}")
            r = r & program_name_array[i -1 ]
          end
          # puts("******** C in AND IS : #{r}")
        elsif ser[:connector] == "OR"
          if i == 1
            r = program_name_array[0] | program_name_array[1]
          else
            r = r | program_name_array[i -1 ]
          end
          # puts("******** C in OR IS : #{r}")
        end
        # puts("********* THE VALUE ID R IS : #{r}")
      end
    end


    r

  end


  def service_group_list

    sg_list = ServiceGroup.where("name ILIKE ?", "%#{params[:search_params][:text]}%").pluck(:name)
    sg_list.delete("Lists & Guides")
    render :json => {status: :ok, sg_list: sg_list }


  end

  def population_group_list

    popg_list = PopulationGroup.where("name ILIKE ?", "%#{params[:search_params][:text]}%").pluck(:name)

    render :json => {status: :ok, popg_list: popg_list }

  end

  def service_tag_list

    stg_list = ServiceTag.where("name ILIKE ?", "%#{params[:search_params][:text]}%").pluck(:name)

    render :json => {status: :ok, stg_list: stg_list }

  end

  def category_list


  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_org
      @org = Org.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def org_params
      params.require(:org).permit(:name, :description_display)
    end
end
