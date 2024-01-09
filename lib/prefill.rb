# frozen_string_literal: true

module Declarations
  module Prefills
    class MonthlyPrefillService < ApplicationService
      SENTRY_OWNER = Constants::SentryOwners::DECLARATIONS

      Error = Exceptions::AppInternalError.with_scope('declarations.prefills.prefill_service')

      class UnsupportedDeclaration < Error; end

      private

      def initialize(declaration:)
        @declaration = declaration
        @company = @declaration.company
      end

      def call
        find_prefill
        return @declaration unless @prefill

        prefill_declaration

        @declaration
      end

      def find_prefill
        @prefill = @company.declaration_prefills.find_by(
          period_start: @declaration.period_start,
          period_end: @declaration.period_end,
          form_type: prefill_form_type,
        )
      end

      def prefill_form_type
        case @declaration
        when VatReturn
          '3310CA3'
        else
          raise UnsupportedDeclaration
        end
      end

      def prefill_declaration
        @declaration = declaration_prefill_class.call(declaration: @declaration, prefill: @prefill)
      end

      def declaration_prefill_class
        case @declaration
        when VatReturn
          Declarations::Prefills::Prefillables::MonthlyVatReturnService
        else
          raise UnsupportedDeclaration
        end
      end
    end
  end
end

