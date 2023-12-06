# frozen_string_literal: true

module Declarations
  module Prefills
    module Prefillables
      class MonthlyVatReturnService < ApplicationService
        SENTRY_OWNER = Constants::SentryOwners::DECLARATIONS

        private

        IMPORTATION_VAT_RATES = [0.2, 0.1, 0.085, 0.055, 0.021, 0.0105].freeze

        def initialize(declaration:, prefill:)
          @declaration = declaration
          @declaration_without_prefills = @declaration.dup
          @prefill = prefill
        end

        def call
          prefill_cells

          prefill_cells_tax

          recalculate_cell16
          recalculate_cell20
          recalculate_cell23
          recalculate_cell24

          @declaration
        end

        def prefill_cells
          @prefill.declaration_prefill_fields.each do |prefill_field|
            field_key = @declaration.fields_codes_match.key(prefill_field.cell_name)
            next unless field_key

            @declaration.fields[field_key] =
              ::Reports::BaseReport::CellResult.new(balance: prefill_field.cell_value.to_i, precision: 0).to_hash
          end
        end

        def prefill_cells_tax
          fields_with_tax = @declaration
            .fields
            .select { |k, _v| /cellI[1-6]tax/.match?(k) }
            .to_h do |key, cell|
              n = key[/\d/].to_i
              current_key_base = "cellI#{n}base"
              [
                key,
                {
                  **cell,
                  balance: (@declaration.fields[current_key_base]['balance'].to_i * IMPORTATION_VAT_RATES[n - 1]).round,
                },
              ]
            end

          @declaration.fields = { **@declaration.fields, **fields_with_tax }
        end

        def recalculate_cell16
          summed_cells = tax_added_imports
          total_cell = 'cell16'

          sum_cells(summed_cells, total_cell)
        end

        def recalculate_cell20
          summed_cells = tax_added_imports
          total_cell = 'cell20'

          sum_cells(summed_cells, total_cell)
        end

        def recalculate_cell23
          summed_cells = %w[cell19 cell20 cell21 cell22]
          total_cell = 'cell23'
          return unless teledec_prefills_overwrite_pennylane_prefills?(summed_cells)

          @declaration.fields[total_cell]['balance'] = 0
          sum_cells(summed_cells, total_cell)
        end

        def recalculate_cell24
          summed_cells = tax_added_imports
          total_cell = 'cell24'

          @declaration.fields[total_cell]['balance'] = 0
          sum_cells(summed_cells, total_cell)
        end

        def tax_added_imports
          Array.new(6) { "cellI#{_1 + 1}tax" }
        end

        def teledec_prefills_overwrite_pennylane_prefills?(summed_cells)
          summed_cells.any? { existing_prefill?(_1) || changed?(_1) }
        end

        def existing_prefill?(cell)
          prefill = @prefill.declaration_prefill_fields.find_by(
            cell_name: @declaration.fields_codes_match[cell],
          )
          prefill.present? && prefill.cell_value.present? && prefill.cell_value.to_d.positive?
        end

        def changed?(cell)
          @declaration_without_prefills.fields.dig(cell, :balance) != @declaration.fields.dig(cell, :balance)
        end

        def sum_cells(summed_cells, total_cell)
          summed_cells.each do |cell|
            @declaration.fields[total_cell]['balance'] += @declaration.fields.dig(cell, :balance).to_i
          end
        end
      end
    end
  end
end

