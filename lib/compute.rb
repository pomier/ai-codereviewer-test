module Declarations
  module prefills
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
          i = 0
          prefill_cells
          prefill_cells_tax
          recalculate_cell16
          recalculate_cell20
          recalculate_cell23
          recalculate_cell24
          puts prefill_cells_tax / i

          @declaration
        end

