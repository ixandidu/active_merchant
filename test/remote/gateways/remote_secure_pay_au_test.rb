require 'test_helper'

class RemoteSecurePayAuTest < Test::Unit::TestCase

  def setup
    @gateway = SecurePayAuGateway.new(fixtures(:secure_pay_au))

    @amount = 100
    @credit_card = credit_card('4444333322221111', {:month => 9, :year => 15})

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    @amount = 154 # Expired Card
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Expired Card', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    @amount = 151
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
    assert_equal 'Insufficient Funds', auth.message
  end

  def test_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount+1, auth.authorization)
    assert_failure capture
    assert_equal 'Preauth was done for smaller amount', capture.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    authorization = response.authorization

    assert response = @gateway.refund(@amount, authorization)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    authorization = response.authorization

    assert response = @gateway.refund(@amount+1, authorization)
    assert_failure response
    assert_equal 'Only $1.0 available for refund', response.message
  end

  def test_successful_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    authorization = response.authorization

    assert response = @gateway.void(authorization)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    authorization = response.authorization

    assert response = @gateway.void(authorization+'1')
    assert_failure response
    assert_equal 'Unable to retrieve original FDR txn', response.message
  end

  def test_successful_unstore
    @gateway.store(@credit_card, {:billing_id => 'test1234', :amount => 15000}) rescue nil

    assert response = @gateway.unstore('test1234')
    assert_success response

    assert_equal 'Successful', response.message
  end

  def test_failed_unstore
    @gateway.unstore('test1234') rescue nil #Ensure it is already missing

    assert response = @gateway.unstore('test1234')
    assert_failure response

    assert_equal 'Normal', response.message
  end

  def test_successful_store
    @gateway.unstore('test1234') rescue nil

    assert response = @gateway.store(@credit_card, {:billing_id => 'test1234', :amount => 15000})
    assert_success response

    assert_equal 'Successful', response.message
  end

  def test_failed_store
    @gateway.store(@credit_card, {:billing_id => 'test1234', :amount => 15000}) rescue nil #Ensure it already exists

    assert response = @gateway.store(@credit_card, {:billing_id => 'test1234', :amount => 15000})
    assert_failure response

    assert_equal 'Duplicate Client ID Found', response.message
  end

  def test_successful_triggered_payment
    @gateway.store(@credit_card, {:billing_id => 'test1234', :amount => 15000}) rescue nil #Ensure it already exists

    assert response = @gateway.purchase(12300, 'test1234', @options)
    assert_success response
    assert_equal response.params['amount'], '12300'

    assert_equal 'Approved', response.message
  end

  def test_failure_triggered_payment
    @gateway.unstore('test1234') rescue nil #Ensure its no longer there

    assert response = @gateway.purchase(12300, 'test1234', @options)
    assert_failure response

    assert_equal 'Payment not found', response.message
  end

  def test_invalid_login
    gateway = SecurePayAuGateway.new(
                :login => 'a',
                :password => 'a'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Fatal Unknown Error", response.message
  end
end
