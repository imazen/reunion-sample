#Mark likely transfers
set_transfer true do 
  txn_types :transfer #Some banks, like PayPal and Chase, identify transfers for our benefit.

  #Others... well, we aren't so lucky
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
end 


tax_expense(:owner_draw) do
  vendors :amazon_video #When the wrong default card was selected
end 


txn_types :return do 
  tag :vendor_refund
end 

txn_types :income do
  tax_expense :income
end 

# return, refund
txn_types :refund do
  tax_expense :refunds
end

txn_types :fee do
  tax_expense :fees
end


tag(:expense) do
  tax_expense :insurance do
    for_vendors :auto_owners_insurance 
  end

  tax_expense :advertising do
    for_vendors :repository_hosting, :github, :appharbor, :aws, :microsoft, :app_net, :heroku
    vendor_tags :advertising
    vendor_tags :job_listings
    vendor_tags :domains
  end 

  tax_expense :supplies do
    vendor_tags :training
  end 

  tax_expense :office do
    vendor_tags :shipping
    vendor_tags :software_service
    vendor_tags :communication
    vendor_tags :office
  end

  tax_expense :home_office do
    for_vendors :time_warner_cable
    for_vendors :duke_energy
  end 

  tax_expense :section179 do
    vendor_tags :hardware
    vendor_tags :software
    for_vendors :apple_store, :microsoft_store, :verizon_store
  end 

  tax_expense :travel do
    vendor_tags :travel
  end 

  tax_expense :misc do
    match("FOREIGN TRANSACTION FEE")
  end
end 









