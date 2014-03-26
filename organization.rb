require 'reunion'

module Reunion
  class MyOrganization < Reunion::Organization

    attr_accessor :root_dir
    attr_reader :bank_accounts, :overrides_path

    #Define the bank account names, currencies, and file tags
    def configure
      return if @is_configured
      @is_configured = true

      @root_dir = File.dirname(__FILE__)

      paypal      = BankAccount.new(name: "PayPal", currency: :USD, permanent_id: :paypal)
      paypal_euro = BankAccount.new(name: "PayPal_Euro", currency: :EUR, permanent_id: :paypal_euro)
      chase       = BankAccount.new(name: "ChaseCC", currency: :USD, permanent_id: :chasecc)
      amex        = BankAccount.new(name: "Amex", currency: :USD, permanent_id: :amex)
      pnc         = BankAccount.new(name: "PNC", currency: :USD, permanent_id: :pnc)
      @bank_accounts = [paypal, paypal_euro, chase, amex, pnc]


      #Because PNC statements and activity exports have different transaction descriptions.
      pnc.add_parser_overlap_deletion(keep_parser: PncStatementActivityCsvParser, discard_parser: PncActivityCsvParser)

      @bank_file_tags = {paypal: [paypal, paypal_euro], 
                         paypal_usd: paypal, 
                         paypal_euro: paypal_euro,
                         chasecc: chase,
                         amex: amex,
                         pnc: pnc}
      @parsers = {
        pncs: PncStatementActivityCsvParser,
        pncacsv: PncActivityCsvParser,
        ppbaptsv: PayPalBalanceAffectingPaymentsTsvParser,
        chasejotcsv: ChaseJotCsvParser,
        chasecsv: ChaseCsvParser,
        tsv: TsvParser,
        tjs: TsvJsParser,
        cjs: CsvJsParser,
        amexqfx: OfxParser,
        chaseqfx: OfxTransactionsParser}

      @locator = l = StandardFileLocator.new 
      l.working_dir = root_dir
      l.input_dirs = ["./input/files"]

      @overrides_path = File.join(root_dir, "/input/overrides.txt")

      @schema = Schema.new({

      account_sym: SymbolField.new(readonly:true), #the permanent ID of the bank account
      id: StringField.new(readonly:true), #bank-provided txn id, if available
      date: DateField.new(readonly:true, critical:true), 
      amount: AmountField.new(readonly:true, critical:true, default_value: 0),
      description: DescriptionField.new(readonly:true, default_value: ""),
      currency: UppercaseSymbolField.new(readonly:true),
      balance_after: AmountField.new(readonly:true), #The balance of the account following the application of the transaction
      txn_type: SymbolField.new, #Sometimes provided. purchase, income, refund, return, transfer, fee, or nil
      transfer: BoolField.new, #If true, transaction will be paird with a matching one in a different account
      discard_if_unmerged: BoolField.new(readonly:true), #If true, this transaction should only contain optional metadata

      description2: DescriptionField.new(readonly:true), #For additional details, like Amazon order items


      #The remainer are simply commonly used conventions 
      tags: TagsField.new,

      vendor: SymbolField.new,
      vendor_description: DescriptionField.new,
      vendor_tags: TagsField.new,

      client: SymbolField.new,
      client_tags: TagsField.new,

      tax_expense: SymbolField.new,
      subledger: SymbolField.new,

      chase_tags: TagsField.new,
      memo: DescriptionField.new

      })
      @syntax = StandardRuleSyntax.new(@schema)
    end

    attr_reader :all_input_files

    def locate_input
      @all_input_files = @locator.generate_and_assign(@parsers, @bank_file_tags)
    end

    def rule_set_descriptors
      [{
        path: "input/rules/vendors.rb",
        name: "Vendors",
        run_count: 1
        },
      {
        path: "input/rules/clients.rb",
        name: "Clients",
        run_count: 1
        },
      {
        path: "input/rules/rules.rb",
        name: "General rules",
        run_count: 2
        }]
    end

  end 

end 