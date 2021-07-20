module OrgsHelper

  def create_program_hash(p)
    program_services = p.service_groups.pluck(:name)
    program_population = p.population_groups.pluck(:name)
    p_service_tags = p.service_tags.pluck(:name).join(", ")
    p_sites = p.sites

    programs = {
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
        "SelectprogramID": p.select_program_id,
        "ServiceAreaDescriptionDisplay": p.service_area_description_display,
        "ServiceTags": p_service_tags
    }

  end

  def create_site_hash(s)

    location = Location.where(sites_id: s.id).first

    if location.nil?
      {}
    else
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
          "InactiveSite": s.inactive.nil? ? false : s.inactive ,
          "LocationName": s.site_name,
          "Name": s.name,
          "OfficePhone": location.phone,
          "POCs": [
              {
                  "id": "1.0",
                  "poc": {
                      # "DefaultPOC": false,
                      "Email": location.email,
                      # "InactivePOC": false,
                      "Name": s.name,
                      "OfficePhone": location.phone
                  }
              }
          ],
          # "ResourceDirectory": false,
          "SelectSiteID": s.select_site_id
          # "ServiceDeliverySite": true
      }
    end

  end

  def create_org_name(org)

    org_name_grab_field = org.grab_lists.where(field_name: "OrganizationName").first

    organizationName = {
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
    }
  end

  def create_scope(org)
    scope = org.scopes.first
    geoScope = {
        "City": scope.city,
        "Country": scope.country,
        "County": scope.county,
        "Neighborhoods": scope.neighborhood,
        "Region": scope.region,
        "Scope": scope.geo_scope,
        "ServiceAreaName": scope.service_area_name,
        "State": scope.state
    }

  end

  def active_programs
    Program.where(inactive: [nil, false])
  end

end
