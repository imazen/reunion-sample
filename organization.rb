require 'reunion'

module Reunion

   class OwnerExpenseTsvParser < TsvParser
    def parse(text)
      results = super(text)
      results[:combined] = results[:combined].map do |t|
        contrib = {}.merge(t)
        contrib[:tax_expense] = :owner_contrib
        contrib[:description] = "Owner contrib: " + contrib[:description]
        contrib[:amount] = parse_amount(contrib[:amount]) * -1
        [contrib,t]
      end.flatten
      results
    end
  end

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
      exex        = BankAccount.new(name: "ExternalExpenses", currency: :USD, permanent_id: :exex)
      @bank_accounts = [paypal, paypal_euro, chase, amex, pnc,exex]

      #When banks use a different sort order depending on the type or time of export, 
      #We can't merge theme without changing the txn order. So we sort them ourselves.
      chase.sort = pnc.sort = exex.sort = :standard 
      paypal.sort = paypal_euro.sort = [:date, :id]

      #Because PNC statements and activity exports have different transaction descriptions.
      pnc.add_parser_overlap_deletion(keep_parser: PncStatementActivityCsvParser, discard_parser: PncActivityCsvParser)

      

      @bank_accounts.each do |bank|
        #When do you start 'accounting'?
        bank.drop_transactions_before(Date.parse('2012-05-15'))
      end 

      @bank_file_tags = {paypal: [paypal, paypal_euro], 
                         paypal_usd: paypal, 
                         paypal_euro: paypal_euro,
                         chasecc: chase,
                         amex: amex,
                         pnc: pnc,
                         exex: exex}
      @parsers = {
        pncs: PncStatementActivityCsvParser,
        pncacsv: PncActivityCsvParser,
        ppbaptsv: PayPalBalanceAffectingPaymentsTsvParser,
        chasejotcsv: ChaseJotCsvParser,
        chasecsv: ChaseCsvParser,
        tsv: TsvParser,
        tjs: TsvParser,
        cjs: CsvParser,
        amexqfx: OfxParser,
        chaseqfx: OfxTransactionsParser,
        otsv: OwnerExpenseTsvParser}

      @locator = l = StandardFileLocator.new 
      l.working_dir = root_dir
      l.input_dirs = ["./input/imports","./input/manual","./input/categorize"]

      @overrides_path = File.join(root_dir, "/input/overrides.txt")

      @schema = Schema.new({id: StringField.new(readonly:true),
       date: DateField.new(readonly:true, critical:true), 
       amount: AmountField.new(readonly:true, critical:true, default_value: 0),
       balance_after: AmountField.new(readonly:true),
       tags: TagsField.new,
       description: DescriptionField.new(readonly:true, default_value: ""),
       description2: DescriptionField.new(readonly:true),
       subledger: SymbolField.new,
       vendor: SymbolField.new,
       vendor_description: DescriptionField.new,
       vendor_tags: TagsField.new,
       client: SymbolField.new,
       client_tags: TagsField.new,
       tax_expense: SymbolField.new,
       account_sym: SymbolField.new(readonly:true),
       transfer: BoolField.new,
       discard_if_unmerged: BoolField.new(readonly:true),
       currency: UppercaseSymbolField.new(readonly:true),
       chase_tags: TagsField.new,
       rebill: SymbolField.new,
       memo: DescriptionField.new,
       product: SymbolField.new,
       txn_type: SymbolField.new
      })

      [:date, :amount, :description, :description2, :subledger, :vendor, :tax_expense, :rebill, :memo, :product].each{|k| schema[k].display_tags << :rebill_form }
      [:date, :amount, :description, :description2, :vendor, :tax_expense, :rebill, :memo, :product].each{|k| schema[k].display_tags << :repl }

      [:date, :amount, :description, :description2, :subledger, :vendor, :tax_expense, :rebill, :memo, :product].each{|k| schema[k].display_tags << :reports }
      

    end

    attr_reader :all_input_files

    def locate_input
      @all_input_files = @locator.generate_and_assign(@parsers, @bank_file_tags)
      @all_input_files.each do |f|
        f.metaonly = true if f.path.include? "cjs"
      end
        
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
        run_count: 3
        }]
    end


    def tax_report
      ByYearReport.new(:tax, 
        title: "Income tax reports & deductions",
        filter: ->(t){ !t[:transfer]},
      group_only: true,
        subreports:[
          Report.new(:paypal_gross_credits,
            filter: ->(t){(t[:txn_type] == :income || t[:txn_type] == :refund) && (t.account_sym == :paypal || t.account_sym == :paypal_euro)}),
          Report.new(:paypal_fees,
            filter: ->(t){t[:txn_type] == :fee && (t.account_sym == :paypal || t.account_sym == :paypal_euro)}),
          Report.new(:google_merchant,
            filter: ->(t){t[:tax_expense] == :income && t[:client] == :google_merchant}),
          
          Report.new(:other_income,
            filter: ->(t){t[:tax_expense] == :income && t[:client] != :google_merchant && t.account_sym != :paypal && t.account_sym != :paypal_euro}),
          
          Report.new(:expense_debits,
            filter: ->(t){t.amount < 0},
            subreports:[FieldValueReport.new(:category, :tax_expense)]
            ),
          Report.new(:expense_credits,
            filter: ->(t){t.amount > 0},
            subreports:[FieldValueReport.new(:category, :tax_expense)]
            ),]
          )
 
    end

    def subledger_reports
      ByYearReport.new(:subledger, 
        title: "Subledger",
        filter: ->(t){ !t[:transfer]},
      group_only: true,
        subreports:[
          FieldValueReport.new(:subledger, :subledger)]
          )
    end

    def quarterly_reports
      QuarterlyReport.new(:quarters, 
        title: "Quarterlies",
        filter: ->(t){ !t[:transfer]},
      group_only: true,
        subreports:[
          FieldValueReport.new(:subledger, :subledger)]
          )
    end

    def reports

      @reports ||= [tax_report, subledger_reports,quarterly_reports]
    end 


  end 

end 