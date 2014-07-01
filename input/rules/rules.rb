#Exclude transfers
tag(:not_transfer).subledger :owner_draw do
  #Paying myself
  account_syms(:pnc).match /\A(TWH AUTO|Online) (Transfer|Payment) To ([X0-9]*BANK NUMBER HERE)\Z/i
end 

#Tag transfers
set_transfer true do 
  txn_types :transfer #Anything classed a transfer by the parsers

  #And.. all the stuff that we have to manually identify due to bank creativity and artistry
  account_syms :pnc do
    match([
      /\AACH (Tel|Web)\-Single Epay Chase [0-9A-z]+\Z/i,
      /\AACH WebSingle [0-9A-z]+ Chase Epay\Z/i,
      /\AACH WEB\-SINGLE [0-9A-Z]+ AMEX EPAYMENT ACH PMT\Z/i,
      /\AACH Web\-Single ACH Pmt Amex Epayment\Z/i,
      /\AACH Credit Transfer Paypal [0-9A-Za-z]+\Z/i,
      /\AACH Credit [0-9A-z]+ Paypal Transfer\Z/i,
    ])
  end
  account_syms :chasecc do
    match "Payment Thank You-Mobile"
  end 
  account_syms :paypal do 
    match ["bank account", "credit card"]
    match /\A(To|From) (U\.S\. Dollar|Euro)\Z/i
  end
  account_syms :amex do
    match "ONLINE PAYMENT - THANK YOU"
  end
end 


#When we get money
subledger :income_consulting do
  clients :oneclient,:twoclient
end
subledger :product_income do
  clients :google_merchant
  txn_types :income
end

#When we give money back
subledger(:rebates).txn_types :refund

#Accidental personal charges on the business card
subledger :owner_draw do
  vendors  :itunes_store, :netflix, :amazon_video, :amazon_services_kindle
end 

#When I pay for a business expense on my own card...
subledger :owner_contrib do
  match "^Owner contrib:"
end

#When the bank takes our money
subledger :paypal_fees do
  txn_types(:fee).account_syms :paypal, :paypal_euro
end
subledger :bank_fees do
  match("FOREIGN TRANSACTION FEE")
  match("^Service Charge")
  match("^Corporate ACH Fee Payroll ")
  match("^ACH Debit Verifybank Paypal ")
  match("^ACH Credit Verifybank Paypal ")
  txn_types(:fee).account_syms :chasecc, :pnc
end



#When I have to pay people to do stuff
subledger :contract_labor  do
  product :oneproduct do
    vendors :independent_vendor
    match "VWORKER"
  end
  product :twoproduct do
    vendors :other_vendor
  end
end

#When the insurance company wants money
subledger(:insurance).tax_expense :insurance do
  for_vendors :auto_owners_insurance 
end

subledger :hosting do
  vendor_tags :hosting
end

subledger :advertising do
  vendor_tags :advertising
  subledger(:domains).vendor_tags(:domains)
  subledger(:job_listings).vendor_tags :job_listings
end 

tax_expense :supplies do
  subledger(:training).vendor_tags :training
end 

subledger(:office) do
  vendor_tags :shipping
  vendor_tags :office
end
subledger(:software).vendor_tags :software_service
subledger(:communication).vendor_tags :communication

subledger(:utilities).for_vendors :time_warner_cable

subledger :home_office_rent do
  for_vendors :mylandlord
end 
subledger :home_office_utilities do
  for_vendors :duke_energy
end


subledger :hardware do
  vendor_tags :hardware
  for_vendors :apple_store, :microsoft_store, :verizon_store
end
subledger(:software).vendor_tags :software
subledger(:travel).vendor_tags :travel




match "^CHECK " do
  after '2013-05-05' do
    amount -1,234.00 do
      subledger(:office_rent).tax_expense :property_rent
    end
    amount -555.00 do
      subledger(:utilities).tax_expense :utilities
    end 
  end 
end 



subledger :travel do
  match(["WWW.HYPERTINY-CHARGE.C","LRAA PARKING", "PAYPAL *UMBRACO",
        "YASURAGI HASSELUDDEN A", "WAXHOLMSBOLAGET", "VERMDO TAXI AB", 
        "HMSHOST SWEDEN AB", "CODEPALOUSA", "COLE PUBLISHING INC",
        "BUSYCONF LLC", "EB *ANCIENT CITY RUBY", "EINDHOVEN AIRPORT"])
end 

date_between '2013-03-14', '2014-03-20' do
  rebill :aclient do
    product :producttwo do
      vendors :stack_overflow, :shiprise, :github,:moo_printing, :vistaprint, :authentic_jobs, :cafepress
      vendors :oreilly, :code_school
    end 
    vendors :skype, :hellofax, :stack_overflow
    tax_expenses :contract_labor
  end

end

rebill :none do
  vendors :ejunkie, :paypal_payflow
  tax_expenses :state_tax, :federal_tax
end 

product :productone do
  vendors :uservoice, :grasshopper, :ejunkie, :appharbor
end 
product :productwo do
  vendors :adobe, :shiprise
end 




tax_expense(:income).subledgers :product_income, :income_consulting
tax_expense(:rebates).subledgers :rebates
tax_expense(:owner_draw).subledgers :owner_draw, :clothing
tax_expense(:other_paypal_transaction_fees).subledgers :paypal_fees
tax_expense(:other_bank_fees).subledgers :bank_fees
tax_expense(:contract_labor).subledgers :contract_labor
tax_expense(:advertising).subledgers :advertising, :hosting, :domains, :job_listings
tax_expense(:office).subledgers :office, :software
tax_expense(:communication).subledgers :communication
tax_expense(:home_office).subledgers(:home_office)
tax_expense(:home_office_insurance).subledgers(:home_office_insurance)
tax_expense(:home_office_rent).subledgers(:home_office_rent)
tax_expense(:home_office_utilities).subledgers(:home_office_utilities)
tax_expense(:health_insurance).subledgers(:health_insurance)

tax_expense(:travel).subledgers :travel, :fuel
tax_expense(:meals).subledgers :meals
tax_expense(:supplies).subledgers :training
tax_expense :section179 do
  for_amounts_below -200.0 do 
    subledgers :hardware
    vendor_tags :software
  end
end
tax_expense :office do
  subledgers :hardware do
    for_amounts_above -200.0
  end
end

