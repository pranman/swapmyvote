require "csv"
require_relative "constituencies_original_with_ons_csv"
require_relative "electoral_calculus_constituencies_tsv"

# This maps Electoral calculus polls data provided per constituency to from usable by SMV
# - EC name is mapped to an ONS id
# - party names mapped to SMV party IDs
# - loop over each party/constituency combo, not over constituencies
# - takes care of mapping the 'nationalist vote' to the appropriate party.

class ElectoralCalculusConstituenciesPollsRaw
  include Enumerable

  def initialize
    @parties_by_party_code = {
      con:    Party.find_by(name: "Conservatives"),
      green:  Party.find_by(name: "Green"),
      lab:    Party.find_by(name: "Labour"),
      libdem: Party.find_by(name: "Liberal Democrats"),
      snp:    Party.find_by(name: "SNP"),
      plaid:  Party.find_by(name: "Plaid Cymru"),
      reform: Party.find_by(name: "Reform")
    }

    missing_parties = @parties_by_party_code.select{ |_key, value| value.nil? }

    raise "Can't find these parties: #{missing_parties.keys}" unless missing_parties.count.zero?
  end

  # rubocop:disable Metrics/MethodLength
  def each
    failed_ons_lookup = Set.new

    ElectoralCalculusConstituenciesTsv.new.each do |data|
      constituency_name = data[:constituency_name]
      constituency_ons_id = constituency_ons_id_from_ec_constituency_name(constituency_name)

      if constituency_ons_id.nil?
        # puts "failed ons id lookup for #{constituency_name} "
        failed_ons_lookup.add(constituency_name)
        next
      end
      country = constituency_ons_id[0]

      if country == "S"
        data[:votes][:snp] = { percent: data[:votes][:nat][:percent], note: "(Assigning nationalist vote to SNP)" }
      elsif country == "W"
        data[:votes][:plaid] = { percent: data[:votes][:nat][:percent], note: "(Assigning nationalist vote to Plaid" }
      elsif %w[S E W N].exclude?(country)
        throw "Invalid country '#{country}' for #{constituency_name};"
      end
      data[:votes].delete(:nat)

      data[:votes].each_key do |party|
        data_transformed = {
          vote_percent: data[:votes][party][:percent].to_f,
          party_id: @parties_by_party_code[party].id,
          party_name: @parties_by_party_code[party].name,
          constituency_ons_id: constituency_ons_id,
          constituency_name: constituency_name,
          conversion_note: data[:votes][party][:note]
        }

        yield data_transformed
      end
    end

    return unless failed_ons_lookup.size.positive?

    puts "\n\nConstituencies where no ONS id found (count: #{failed_ons_lookup.size})"
    pp failed_ons_lookup.to_a.sort
  end

  private def constituency_ons_id_from_ec_constituency_name(name)
    # right now, this misses just 78 constituencies.
    # expect to fix this by calling alternative lookups if the my_soc one returns a nil
    # looks like we'll find a few in the pattern "Hampshire East" <=> "East Hampshire"
    my_soc_constituency_ons_ids_by_name[name]
  end

  private def my_soc_constituency_ons_ids_by_name
    return @my_soc_constituency_ons_ids_by_name if defined?(@my_soc_constituency_ons_ids_by_name)

    hash = {}
    MysocietyConstituenciesCsv.new.each do |c|
      hash[c[:name]] = c[:ons_id]
    end

    return @my_soc_constituency_ons_ids_by_name = hash
  end
end
