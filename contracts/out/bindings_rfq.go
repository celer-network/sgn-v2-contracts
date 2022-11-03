// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package rfq

import (
	"errors"
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = errors.New
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
)

// MsgDataTypesRouteInfo is an auto generated low-level Go binding around an user-defined struct.
type MsgDataTypesRouteInfo struct {
	Sender     common.Address
	Receiver   common.Address
	SrcChainId uint64
	SrcTxHash  [32]byte
}

// RFQQuote is an auto generated low-level Go binding around an user-defined struct.
type RFQQuote struct {
	SrcChainId        uint64
	SrcToken          common.Address
	SrcAmount         *big.Int
	DstChainId        uint64
	DstToken          common.Address
	DstAmount         *big.Int
	Deadline          uint64
	Nonce             uint64
	Sender            common.Address
	Receiver          common.Address
	RefundTo          common.Address
	LiquidityProvider common.Address
}

// RfqMetaData contains all meta data concerning the Rfq contract.
var RfqMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_messageBus\",\"type\":\"address\"}],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"}],\"name\":\"DstTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"treasuryAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"FeeCollected\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint64[]\",\"name\":\"chainIds\",\"type\":\"uint64[]\"},{\"indexed\":false,\"internalType\":\"uint32[]\",\"name\":\"feePercs\",\"type\":\"uint32[]\"}],\"name\":\"FeePercUpdated\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"messageBus\",\"type\":\"address\"}],\"name\":\"MessageBusUpdated\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"}],\"name\":\"MessageReceived\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Paused\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"PauserAdded\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"PauserRemoved\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"}],\"name\":\"RefundInitiated\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"Refunded\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint64[]\",\"name\":\"chainIds\",\"type\":\"uint64[]\"},{\"indexed\":false,\"internalType\":\"address[]\",\"name\":\"remoteRfqContracts\",\"type\":\"address[]\"}],\"name\":\"RfqContractsUpdated\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"dstChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"dstToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"dstAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"deadline\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nonce\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liquidityProvider\",\"type\":\"address\"}],\"indexed\":false,\"internalType\":\"structRFQ.Quote\",\"name\":\"detail\",\"type\":\"tuple\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"srcRecipient\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"submissionDeadline\",\"type\":\"uint64\"}],\"name\":\"SrcDeposited\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"srcRecipient\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"SrcReleased\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"treasuryAddr\",\"type\":\"address\"}],\"name\":\"TreasuryAddrUpdated\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Unpaused\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"addPauser\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"_amount\",\"type\":\"uint256\"}],\"name\":\"collectFee\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"dstChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"dstToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"dstAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"deadline\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nonce\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liquidityProvider\",\"type\":\"address\"}],\"internalType\":\"structRFQ.Quote\",\"name\":\"_quote\",\"type\":\"tuple\"}],\"name\":\"dstTransfer\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"_sender\",\"type\":\"bytes\"},{\"internalType\":\"uint64\",\"name\":\"_srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes\",\"name\":\"_message\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"_executor\",\"type\":\"address\"}],\"name\":\"executeMessage\",\"outputs\":[{\"internalType\":\"enumIMessageReceiverApp.ExecutionStatus\",\"name\":\"\",\"type\":\"uint8\"}],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_sender\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"_srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes\",\"name\":\"_message\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"executeMessage\",\"outputs\":[{\"internalType\":\"enumIMessageReceiverApp.ExecutionStatus\",\"name\":\"\",\"type\":\"uint8\"}],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"_token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"_amount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"_srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes\",\"name\":\"_message\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"_executor\",\"type\":\"address\"}],\"name\":\"executeMessageWithTransfer\",\"outputs\":[{\"internalType\":\"enumIMessageReceiverApp.ExecutionStatus\",\"name\":\"\",\"type\":\"uint8\"}],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"_token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"_amount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"_srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes\",\"name\":\"_message\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"_executor\",\"type\":\"address\"}],\"name\":\"executeMessageWithTransferFallback\",\"outputs\":[{\"internalType\":\"enumIMessageReceiverApp.ExecutionStatus\",\"name\":\"\",\"type\":\"uint8\"}],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"_amount\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"_message\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"_executor\",\"type\":\"address\"}],\"name\":\"executeMessageWithTransferRefund\",\"outputs\":[{\"internalType\":\"enumIMessageReceiverApp.ExecutionStatus\",\"name\":\"\",\"type\":\"uint8\"}],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"dstChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"dstToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"dstAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"deadline\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nonce\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liquidityProvider\",\"type\":\"address\"}],\"internalType\":\"structRFQ.Quote\",\"name\":\"_quote\",\"type\":\"tuple\"},{\"internalType\":\"bytes\",\"name\":\"_message\",\"type\":\"bytes\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"srcTxHash\",\"type\":\"bytes32\"}],\"internalType\":\"structMsgDataTypes.RouteInfo\",\"name\":\"_route\",\"type\":\"tuple\"},{\"internalType\":\"bytes[]\",\"name\":\"_sigs\",\"type\":\"bytes[]\"},{\"internalType\":\"address[]\",\"name\":\"_signers\",\"type\":\"address[]\"},{\"internalType\":\"uint256[]\",\"name\":\"_powers\",\"type\":\"uint256[]\"}],\"name\":\"executeRefund\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"name\":\"executedQuotes\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"feePercGlobal\",\"outputs\":[{\"internalType\":\"uint32\",\"name\":\"\",\"type\":\"uint32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"name\":\"feePercOverride\",\"outputs\":[{\"internalType\":\"uint32\",\"name\":\"\",\"type\":\"uint32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"dstChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"dstToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"dstAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"deadline\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nonce\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liquidityProvider\",\"type\":\"address\"}],\"internalType\":\"structRFQ.Quote\",\"name\":\"_quote\",\"type\":\"tuple\"}],\"name\":\"getQuoteHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"_dstChainId\",\"type\":\"uint64\"},{\"internalType\":\"uint256\",\"name\":\"_amount\",\"type\":\"uint256\"}],\"name\":\"getRFQFee\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"isPauser\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"messageBus\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"paused\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"pausers\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"name\":\"quotes\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"name\":\"remoteRfqContracts\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"removePauser\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renouncePauser\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"dstChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"dstToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"dstAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"deadline\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nonce\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liquidityProvider\",\"type\":\"address\"}],\"internalType\":\"structRFQ.Quote\",\"name\":\"_quote\",\"type\":\"tuple\"},{\"internalType\":\"bytes\",\"name\":\"_message\",\"type\":\"bytes\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"srcTxHash\",\"type\":\"bytes32\"}],\"internalType\":\"structMsgDataTypes.RouteInfo\",\"name\":\"_route\",\"type\":\"tuple\"},{\"internalType\":\"bytes[]\",\"name\":\"_sigs\",\"type\":\"bytes[]\"},{\"internalType\":\"address[]\",\"name\":\"_signers\",\"type\":\"address[]\"},{\"internalType\":\"uint256[]\",\"name\":\"_powers\",\"type\":\"uint256[]\"}],\"name\":\"requestRefund\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64[]\",\"name\":\"_chainIds\",\"type\":\"uint64[]\"},{\"internalType\":\"uint32[]\",\"name\":\"_feePercs\",\"type\":\"uint32[]\"}],\"name\":\"setFeePerc\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_messageBus\",\"type\":\"address\"}],\"name\":\"setMessageBus\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64[]\",\"name\":\"_chainIds\",\"type\":\"uint64[]\"},{\"internalType\":\"address[]\",\"name\":\"_remoteRfqContracts\",\"type\":\"address[]\"}],\"name\":\"setRemoteRfqContracts\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_treasuryAddr\",\"type\":\"address\"}],\"name\":\"setTreasuryAddr\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"dstChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"dstToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"dstAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"deadline\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nonce\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liquidityProvider\",\"type\":\"address\"}],\"internalType\":\"structRFQ.Quote\",\"name\":\"_quote\",\"type\":\"tuple\"},{\"internalType\":\"uint64\",\"name\":\"_submissionDeadline\",\"type\":\"uint64\"}],\"name\":\"srcDeposit\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"srcToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"dstChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"dstToken\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"dstAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"deadline\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nonce\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liquidityProvider\",\"type\":\"address\"}],\"internalType\":\"structRFQ.Quote\",\"name\":\"_quote\",\"type\":\"tuple\"},{\"internalType\":\"bytes\",\"name\":\"_message\",\"type\":\"bytes\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"srcTxHash\",\"type\":\"bytes32\"}],\"internalType\":\"structMsgDataTypes.RouteInfo\",\"name\":\"_route\",\"type\":\"tuple\"},{\"internalType\":\"bytes[]\",\"name\":\"_sigs\",\"type\":\"bytes[]\"},{\"internalType\":\"address[]\",\"name\":\"_signers\",\"type\":\"address[]\"},{\"internalType\":\"uint256[]\",\"name\":\"_powers\",\"type\":\"uint256[]\"}],\"name\":\"srcRelease\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"treasuryAddr\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"name\":\"unconsumedMsg\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"unpause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
	Bin: "0x60806040523480156200001157600080fd5b50604051620038833803806200388383398101604081905262000034916200019a565b6200003f3362000082565b6001805460ff60a01b191690556200005733620000d2565b6001600381905580546001600160a01b0319166001600160a01b0392909216919091179055620001cc565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6001600160a01b03811660009081526002602052604090205460ff1615620001405760405162461bcd60e51b815260206004820152601960248201527f4163636f756e7420697320616c72656164792070617573657200000000000000604482015260640160405180910390fd5b6001600160a01b038116600081815260026020908152604091829020805460ff1916600117905590519182527f6719d08c1888103bea251a4ed56406bd0c3e69723c8a1686e017e7bbe159b6f8910160405180910390a150565b600060208284031215620001ad57600080fd5b81516001600160a01b0381168114620001c557600080fd5b9392505050565b6136a780620001dc6000396000f3fe6080604052600436106102345760003560e01c80636ef8d66d11610138578063aa2003ea116100b0578063cc47e4001161007f578063df1f64ef11610064578063df1f64ef14610673578063f2fde38b146106a3578063fae3b92c146106c357600080fd5b8063cc47e4001461062a578063d129153c1461066057600080fd5b8063aa2003ea1461059a578063ab9341fd146105ca578063abd23f8b146105ea578063cbac44df1461060a57600080fd5b80638456cb59116101075780639c649fdf116100ec5780639c649fdf14610547578063a1a227fa1461055a578063a7e05b9c1461057a57600080fd5b80638456cb59146105145780638da5cb5b1461052957600080fd5b80636ef8d66d146104af5780637cd2bffc1461044a57806380f51c12146104c457806382dc1ec4146104f457600080fd5b80633e07d172116101cb578063547cad121161019a5780635bf9f32b1161017f5780635bf9f32b1461045d5780635c975abb146104705780636b2c0f551461048f57600080fd5b8063547cad121461042a5780635ab7afc61461044a57600080fd5b80633e07d172146103895780633e73b92c146103bc5780633f4ba83a146103dc57806346fbf68e146103f157600080fd5b806325329eaf1161020757806325329eaf146102dc5780632ca79b4d1461031c5780632ec0ff6c1461032f57806330d9a62a1461035157600080fd5b8063063ce4e514610239578063089062fe146102625780630bcb4982146102905780630bd930b4146102a3575b600080fd5b61024c610247366004612a96565b6106e3565b6040516102599190612b29565b60405180910390f35b34801561026e57600080fd5b5061028261027d366004612b51565b61074f565b604051908152602001610259565b61024c61029e366004612b7b565b6107ac565b3480156102af57600080fd5b506008546102c790600160a01b900463ffffffff1681565b60405163ffffffff9091168152602001610259565b3480156102e857600080fd5b5061030c6102f7366004612bea565b60066020526000908152604090205460ff1681565b6040519015158152602001610259565b61028261032a366004612c1c565b610812565b34801561033b57600080fd5b5061034f61034a366004612c52565b610cb7565b005b34801561035d57600080fd5b50600854610371906001600160a01b031681565b6040516001600160a01b039091168152602001610259565b34801561039557600080fd5b506102c76103a4366004612c6e565b60096020526000908152604090205463ffffffff1681565b3480156103c857600080fd5b5061034f6103d7366004612ce0565b610de4565b3480156103e857600080fd5b5061034f611027565b3480156103fd57600080fd5b5061030c61040c366004612dd3565b6001600160a01b031660009081526002602052604090205460ff1690565b34801561043657600080fd5b5061034f610445366004612dd3565b611090565b61024c610458366004612dee565b61114e565b61034f61046b366004612e7e565b6111b6565b34801561047c57600080fd5b50600154600160a01b900460ff1661030c565b34801561049b57600080fd5b5061034f6104aa366004612dd3565b611485565b3480156104bb57600080fd5b5061034f6114fa565b3480156104d057600080fd5b5061030c6104df366004612dd3565b60026020526000908152604090205460ff1681565b34801561050057600080fd5b5061034f61050f366004612dd3565b611503565b34801561052057600080fd5b5061034f611575565b34801561053557600080fd5b506000546001600160a01b0316610371565b61024c610555366004612e9b565b6115dc565b34801561056657600080fd5b50600154610371906001600160a01b031681565b34801561058657600080fd5b5061034f610595366004612dd3565b6116e3565b3480156105a657600080fd5b5061030c6105b5366004612bea565b60076020526000908152604090205460ff1681565b3480156105d657600080fd5b5061034f6105e5366004612ee6565b61179a565b3480156105f657600080fd5b5061034f610605366004612ce0565b611a1b565b34801561061657600080fd5b5061034f610625366004612ee6565b611c3a565b34801561063657600080fd5b50610371610645366004612c6e565b6004602052600090815260409020546001600160a01b031681565b61034f61066e366004612ce0565b611dc1565b34801561067f57600080fd5b5061030c61068e366004612bea565b60056020526000908152604090205460ff1681565b3480156106af57600080fd5b5061034f6106be366004612dd3565b61206c565b3480156106cf57600080fd5b506102826106de366004612e7e565b61215a565b6001546000906001600160a01b031633146107455760405162461bcd60e51b815260206004820152601960248201527f63616c6c6572206973206e6f74206d657373616765206275730000000000000060448201526064015b60405180910390fd5b9695505050505050565b67ffffffffffffffff821660009081526009602052604081205463ffffffff16806107865750600854600160a01b900463ffffffff165b620f424061079a63ffffffff831685612f68565b6107a49190612f87565b949350505050565b6001546000906001600160a01b031633146108095760405162461bcd60e51b815260206004820152601960248201527f63616c6c6572206973206e6f74206d6573736167652062757300000000000000604482015260640161073c565b95945050505050565b600154600090600160a01b900460ff16156108625760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b604482015260640161073c565b428267ffffffffffffffff16116108bb5760405162461bcd60e51b815260206004820152601860248201527f70617374207375626d697373696f6e20646561646c696e650000000000000000604482015260640161073c565b60006108cf61014085016101208601612dd3565b6001600160a01b031614158015610901575060006108f561018085016101608601612dd3565b6001600160a01b031614155b6109735760405162461bcd60e51b815260206004820152603660248201527f726563656976657220616e64206c697175696469747950726f7669646572207360448201527f686f756c64206e6f742062652030206164647265737300000000000000000000606482015260840161073c565b67ffffffffffffffff461661098b6020850185612c6e565b67ffffffffffffffff16146109e25760405162461bcd60e51b815260206004820152601460248201527f6d69736d617463682073726320636861696e4964000000000000000000000000604482015260640161073c565b336109f561012085016101008601612dd3565b6001600160a01b031614610a4b5760405162461bcd60e51b815260206004820152601160248201527f6d69736d61746368207573722061646472000000000000000000000000000000604482015260640161073c565b6000610a568461215a565b60008181526006602052604090205490915060ff1615610ab85760405162461bcd60e51b815260206004820152601360248201527f7374696c6c2070656e64696e67206f7264657200000000000000000000000000604482015260640161073c565b6000610ad7610acd6080870160608801612c6e565b866040013561074f565b90508460400135811115610b535760405162461bcd60e51b815260206004820152602660248201527f746f6f20736d616c6c20616d6f756e7420746f20636f7665722070726f746f6360448201527f6f6c206665650000000000000000000000000000000000000000000000000000606482015260840161073c565b610b7d333060408801803590610b6c9060208b01612dd3565b6001600160a01b0316929190612244565b6000828152600660205260408120805460ff19166001179055600481610ba96080890160608a01612c6e565b67ffffffffffffffff1681526020810191909152604001600020546001600160a01b0316905080610c1c5760405162461bcd60e51b815260206004820152601c60248201527f6e6f2072667120636f6e7472616374206f6e2064737420636861696e00000000604482015260640161073c565b600083604051602001610c3191815260200190565b60408051601f198184030181529190529050610c5e82610c5760808a0160608b01612c6e565b83346122e2565b7ff540b19255a5c60a71a508bc7b079957ecabf5b2c16cd7ad708a94417dd16b5e8488610c9361018082016101608301612dd3565b89604051610ca49493929190612fa9565b60405180910390a1509195945050505050565b33610cca6000546001600160a01b031690565b6001600160a01b031614610d205760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161073c565b6008546001600160a01b0316610d785760405162461bcd60e51b815260206004820152601260248201527f3020747265617375727920616464726573730000000000000000000000000000604482015260640161073c565b600854610d92906001600160a01b038481169116836122fe565b600854604080516001600160a01b039283168152918416602083015281018290527ff228de527fc1b9843baac03b9a04565473a263375950e63435d4138464386f469060600160405180910390a15050565b60026003541415610e375760405162461bcd60e51b815260206004820152601f60248201527f5265656e7472616e637947756172643a207265656e7472616e742063616c6c00604482015260640161073c565b6002600355600154600160a01b900460ff1615610e895760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b604482015260640161073c565b6000610e948b61215a565b9050610ea88a8a8a8a8a8a8a8a8a8a612333565b60008181526006602052604090205460ff161515600114610f0b5760405162461bcd60e51b815260206004820152601860248201527f696e636f72726563742061677265656d656e7420686173680000000000000000604482015260640161073c565b6000818152600660209081526040808320805460ff19908116909155600590925282208054909116905580610f486101608e016101408f01612dd3565b6001600160a01b031614610f6d57610f686101608d016101408e01612dd3565b610f7f565b610f7f6101208d016101008e01612dd3565b9050610fad818d604001358e6020016020810190610f9d9190612dd3565b6001600160a01b031691906122fe565b7f2e0668a62a5f556368dca9c7113e20f2852c05155548243804bf714ce72b25a682828e6020016020810190610fe39190612dd3565b604080519384526001600160a01b0392831660208501529116828201528e013560608201526080015b60405180910390a15050600160035550505050505050505050565b3360009081526002602052604090205460ff166110865760405162461bcd60e51b815260206004820152601460248201527f43616c6c6572206973206e6f7420706175736572000000000000000000000000604482015260640161073c565b61108e61244b565b565b336110a36000546001600160a01b031690565b6001600160a01b0316146110f95760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161073c565b600180546001600160a01b0319166001600160a01b0383169081179091556040519081527f3f8223bcd8b3b875473e9f9e14e1ad075451a2b5ffd31591655da9a01516bf5e906020015b60405180910390a150565b6001546000906001600160a01b031633146111ab5760405162461bcd60e51b815260206004820152601960248201527f63616c6c6572206973206e6f74206d6573736167652062757300000000000000604482015260640161073c565b979650505050505050565b600154600160a01b900460ff16156112035760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b604482015260640161073c565b4261121460e0830160c08401612c6e565b67ffffffffffffffff161161126b5760405162461bcd60e51b815260206004820152601560248201527f706173742072656c6561736520646561646c696e650000000000000000000000604482015260640161073c565b67ffffffffffffffff46166112866080830160608401612c6e565b67ffffffffffffffff16146112dd5760405162461bcd60e51b815260206004820152601460248201527f6d69736d617463682064737420636861696e4964000000000000000000000000604482015260640161073c565b60006112e88261215a565b60008181526007602052604090205490915060ff161561134a5760405162461bcd60e51b815260206004820152601660248201527f71756f746520616c726561647920657865637574656400000000000000000000604482015260640161073c565b6113743361136061014085016101208601612dd3565b60a08501803590610b6c9060808801612dd3565b60008181526007602090815260408220805460ff1916600117905560049082906113a090860186612c6e565b67ffffffffffffffff1681526020810191909152604001600020546001600160a01b03169050806114135760405162461bcd60e51b815260206004820152601c60248201527f6e6f2072667120636f6e7472616374206f6e2073726320636861696e00000000604482015260640161073c565b60008260405160200161142891815260200190565b60408051601f19818403018152919052905061144b82610c576020870187612c6e565b6040518381527f3e9151a84654790f7b6b716dd4e3ff3f520fc83caa56d52a28f0b98f81c7e778906020015b60405180910390a150505050565b336114986000546001600160a01b031690565b6001600160a01b0316146114ee5760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161073c565b6114f7816124f1565b50565b61108e336124f1565b336115166000546001600160a01b031690565b6001600160a01b03161461156c5760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161073c565b6114f7816125aa565b3360009081526002602052604090205460ff166115d45760405162461bcd60e51b815260206004820152601460248201527f43616c6c6572206973206e6f7420706175736572000000000000000000000000604482015260640161073c565b61108e612667565b6001546000906001600160a01b031633146116395760405162461bcd60e51b815260206004820152601960248201527f63616c6c6572206973206e6f74206d6573736167652062757300000000000000604482015260640161073c565b67ffffffffffffffff85166000908152600460205260409020546001600160a01b039081169087168114611671576002915050610809565b600061167f85870187612bea565b60008181526005602052604090819020805460ff19166001179055519091507fe29dc34207c78fc0f6048a32f159139c33339c6d6df8b07dcd33f6d699ff2327906116cd9083815260200190565b60405180910390a1506001979650505050505050565b336116f66000546001600160a01b031690565b6001600160a01b03161461174c5760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161073c565b600880546001600160a01b0319166001600160a01b0383169081179091556040519081527fb17659014001857e7557191ad74dc9e967b181eaed0895975325e3848debbc4290602001611143565b336117ad6000546001600160a01b031690565b6001600160a01b0316146118035760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161073c565b8281146118445760405162461bcd60e51b815260206004820152600f60248201526e0dad2e6dac2e8c6d040d8cadccee8d608b1b604482015260640161073c565b60005b838110156119e557620f424083838381811061186557611865613133565b905060200201602081019061187a919061315d565b63ffffffff16106118cd5760405162461bcd60e51b815260206004820152601860248201527f746f6f206c61726765206665652070657263656e746167650000000000000000604482015260640161073c565b8484828181106118df576118df613133565b90506020020160208101906118f49190612c6e565b67ffffffffffffffff1661194e5782828281811061191457611914613133565b9050602002016020810190611929919061315d565b600860146101000a81548163ffffffff021916908363ffffffff1602179055506119d3565b82828281811061196057611960613133565b9050602002016020810190611975919061315d565b6009600087878581811061198b5761198b613133565b90506020020160208101906119a09190612c6e565b67ffffffffffffffff1681526020810191909152604001600020805463ffffffff191663ffffffff929092169190911790555b806119dd81613178565b915050611847565b507f541df5e570cf10ffe04899eebd9eebebd1c54e2bd4af9f24b23fb4a40c6ea00b8484848460405161147794939291906131db565b60026003541415611a6e5760405162461bcd60e51b815260206004820152601f60248201527f5265656e7472616e637947756172643a207265656e7472616e742063616c6c00604482015260640161073c565b6002600355600154600160a01b900460ff1615611ac05760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b604482015260640161073c565b6000611acb8b61215a565b9050611adf8a8a8a8a8a8a8a8a8a8a612333565b60008181526006602052604090205460ff161515600114611b425760405162461bcd60e51b815260206004820152601860248201527f696e636f72726563742061677265656d656e7420686173680000000000000000604482015260640161073c565b6000611b61611b5760808e0160608f01612c6e565b8d6040013561074f565b611b6f9060408e013561323b565b6000838152600660209081526040808320805460ff199081169091556005909252909120805490911690559050611bc5611bb16101808e016101608f01612dd3565b828e6020016020810190610f9d9190612dd3565b7ff29b32a17c591b8b3b1216ce0ffb67c07f3478e99b50c5ccf8602878b1ee6376828d610160016020810190611bfb9190612dd3565b8e6020016020810190611c0e9190612dd3565b604080519384526001600160a01b0392831660208501529116908201526060810183905260800161100c565b33611c4d6000546001600160a01b031690565b6001600160a01b031614611ca35760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161073c565b828114611ce45760405162461bcd60e51b815260206004820152600f60248201526e0dad2e6dac2e8c6d040d8cadccee8d608b1b604482015260640161073c565b60005b83811015611d8b57828282818110611d0157611d01613133565b9050602002016020810190611d169190612dd3565b60046000878785818110611d2c57611d2c613133565b9050602002016020810190611d419190612c6e565b67ffffffffffffffff168152602081019190915260400160002080546001600160a01b0319166001600160a01b039290921691909117905580611d8381613178565b915050611ce7565b507fb4739c640c5970d8ce88b6c31f3706099efca660e282d47b0a267a0bb572d8b784848484604051611477949392919061328e565b60026003541415611e145760405162461bcd60e51b815260206004820152601f60248201527f5265656e7472616e637947756172643a207265656e7472616e742063616c6c00604482015260640161073c565b6002600355600154600160a01b900460ff1615611e665760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b604482015260640161073c565b42611e7760e08c0160c08d01612c6e565b67ffffffffffffffff1610611ece5760405162461bcd60e51b815260206004820152601960248201527f6e6f7420706173742072656c6561736520646561646c696e6500000000000000604482015260640161073c565b6000611ed98b61215a565b9050611eed8a8a8a8a8a8a8a8a8a8a612333565b60008181526007602052604090205460ff1615611f4c5760405162461bcd60e51b815260206004820152601660248201527f71756f746520616c726561647920657865637574656400000000000000000000604482015260640161073c565b60008181526005602090815260408220805460ff191690556004908290611f75908f018f612c6e565b67ffffffffffffffff1681526020810191909152604001600020546001600160a01b0316905080611fe85760405162461bcd60e51b815260206004820152601c60248201527f6e6f2072667120636f6e7472616374206f6e2073726320636861696e00000000604482015260640161073c565b600082604051602001611ffd91815260200190565b6040516020818303038152906040529050612025828e6000016020810190610c579190612c6e565b6040518381527f7cdd4403cff3a09d96c1ffe4ad1cc5c195e9053463a55edfc2944644ec0221189060200160405180910390a1505060016003555050505050505050505050565b3361207f6000546001600160a01b031690565b6001600160a01b0316146120d55760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161073c565b6001600160a01b0381166121515760405162461bcd60e51b815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201527f6464726573730000000000000000000000000000000000000000000000000000606482015260840161073c565b6114f7816126ef565b60006121696020830183612c6e565b6121796040840160208501612dd3565b604084013561218e6080860160608701612c6e565b61219e60a0870160808801612dd3565b60a08701356121b360e0890160c08a01612c6e565b6121c46101008a0160e08b01612c6e565b6121d66101208b016101008c01612dd3565b6121e86101408c016101208d01612dd3565b6121fa6101608d016101408e01612dd3565b61220c6101808e016101608f01612dd3565b6040516020016122279c9b9a999897969594939291906132b5565b604051602081830303815290604052805190602001209050919050565b6040516001600160a01b03808516602483015283166044820152606481018290526122dc9085906323b872dd60e01b906084015b60408051601f198184030181529190526020810180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff167fffffffff000000000000000000000000000000000000000000000000000000009093169290921790915261273f565b50505050565b6001546122dc908590859085906001600160a01b031685612824565b6040516001600160a01b03831660248201526044810182905261232e90849063a9059cbb60e01b90606401612278565b505050565b60006123418a8c018c612bea565b90508082146123925760405162461bcd60e51b815260206004820152601760248201527f6d69736d617463682061677265656d656e742068617368000000000000000000604482015260640161073c565b60008281526005602052604090205460ff1661241b576001546040516311a28b4160e21b81526001600160a01b039091169063468a2d04906123e8908e908e908e908e908e908e908e908e908e9060040161344c565b600060405180830381600087803b15801561240257600080fd5b505af1158015612416573d6000803e3d6000fd5b505050505b60008281526005602052604090205460ff16151560011461243e5761243e613580565b5050505050505050505050565b600154600160a01b900460ff166124a45760405162461bcd60e51b815260206004820152601460248201527f5061757361626c653a206e6f7420706175736564000000000000000000000000604482015260640161073c565b6001805460ff60a01b191690557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516001600160a01b03909116815260200160405180910390a1565b6001600160a01b03811660009081526002602052604090205460ff166125595760405162461bcd60e51b815260206004820152601560248201527f4163636f756e74206973206e6f74207061757365720000000000000000000000604482015260640161073c565b6001600160a01b038116600081815260026020908152604091829020805460ff1916905590519182527fcd265ebaf09df2871cc7bd4133404a235ba12eff2041bb89d9c714a2621c7c7e9101611143565b6001600160a01b03811660009081526002602052604090205460ff16156126135760405162461bcd60e51b815260206004820152601960248201527f4163636f756e7420697320616c72656164792070617573657200000000000000604482015260640161073c565b6001600160a01b038116600081815260026020908152604091829020805460ff1916600117905590519182527f6719d08c1888103bea251a4ed56406bd0c3e69723c8a1686e017e7bbe159b6f89101611143565b600154600160a01b900460ff16156126b45760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b604482015260640161073c565b6001805460ff60a01b1916600160a01b1790557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2586124d43390565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6000612794826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b031661288f9092919063ffffffff16565b80519091501561232e57808060200190518101906127b29190613596565b61232e5760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e60448201527f6f74207375636365656400000000000000000000000000000000000000000000606482015260840161073c565b604051634f9e72ad60e11b81526001600160a01b03831690639f3ce55a90839061285690899089908990600401613610565b6000604051808303818588803b15801561286f57600080fd5b505af1158015612883573d6000803e3d6000fd5b50505050505050505050565b606061289e84846000856128a8565b90505b9392505050565b6060824710156129205760405162461bcd60e51b815260206004820152602660248201527f416464726573733a20696e73756666696369656e742062616c616e636520666f60448201527f722063616c6c0000000000000000000000000000000000000000000000000000606482015260840161073c565b6001600160a01b0385163b6129775760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000604482015260640161073c565b600080866001600160a01b031685876040516129939190613642565b60006040518083038185875af1925050503d80600081146129d0576040519150601f19603f3d011682016040523d82523d6000602084013e6129d5565b606091505b50915091506111ab828286606083156129ef5750816128a1565b8251156129ff5782518084602001fd5b8160405162461bcd60e51b815260040161073c919061365e565b60008083601f840112612a2b57600080fd5b50813567ffffffffffffffff811115612a4357600080fd5b602083019150836020828501011115612a5b57600080fd5b9250929050565b803567ffffffffffffffff81168114612a7a57600080fd5b919050565b80356001600160a01b0381168114612a7a57600080fd5b60008060008060008060808789031215612aaf57600080fd5b863567ffffffffffffffff80821115612ac757600080fd5b612ad38a838b01612a19565b9098509650869150612ae760208a01612a62565b95506040890135915080821115612afd57600080fd5b50612b0a89828a01612a19565b9094509250612b1d905060608801612a7f565b90509295509295509295565b6020810160038310612b4b57634e487b7160e01b600052602160045260246000fd5b91905290565b60008060408385031215612b6457600080fd5b612b6d83612a62565b946020939093013593505050565b600080600080600060808688031215612b9357600080fd5b612b9c86612a7f565b945060208601359350604086013567ffffffffffffffff811115612bbf57600080fd5b612bcb88828901612a19565b9094509250612bde905060608701612a7f565b90509295509295909350565b600060208284031215612bfc57600080fd5b5035919050565b60006101808284031215612c1657600080fd5b50919050565b6000806101a08385031215612c3057600080fd5b612c3a8484612c03565b9150612c496101808401612a62565b90509250929050565b60008060408385031215612c6557600080fd5b612b6d83612a7f565b600060208284031215612c8057600080fd5b6128a182612a62565b600060808284031215612c1657600080fd5b60008083601f840112612cad57600080fd5b50813567ffffffffffffffff811115612cc557600080fd5b6020830191508360208260051b8501011115612a5b57600080fd5b6000806000806000806000806000806102808b8d031215612d0057600080fd5b612d0a8c8c612c03565b99506101808b013567ffffffffffffffff80821115612d2857600080fd5b612d348e838f01612a19565b909b509950899150612d4a8e6101a08f01612c89565b98506102208d0135915080821115612d6157600080fd5b612d6d8e838f01612c9b565b90985096506102408d0135915080821115612d8757600080fd5b612d938e838f01612c9b565b90965094506102608d0135915080821115612dad57600080fd5b50612dba8d828e01612c9b565b915080935050809150509295989b9194979a5092959850565b600060208284031215612de557600080fd5b6128a182612a7f565b600080600080600080600060c0888a031215612e0957600080fd5b612e1288612a7f565b9650612e2060208901612a7f565b955060408801359450612e3560608901612a62565b9350608088013567ffffffffffffffff811115612e5157600080fd5b612e5d8a828b01612a19565b9094509250612e70905060a08901612a7f565b905092959891949750929550565b60006101808284031215612e9157600080fd5b6128a18383612c03565b600080600080600060808688031215612eb357600080fd5b612ebc86612a7f565b9450612eca60208701612a62565b9350604086013567ffffffffffffffff811115612bbf57600080fd5b60008060008060408587031215612efc57600080fd5b843567ffffffffffffffff80821115612f1457600080fd5b612f2088838901612c9b565b90965094506020870135915080821115612f3957600080fd5b50612f4687828801612c9b565b95989497509550505050565b634e487b7160e01b600052601160045260246000fd5b6000816000190483118215151615612f8257612f82612f52565b500290565b600082612fa457634e487b7160e01b600052601260045260246000fd5b500490565b8481526101e08101612fcf60208301612fc187612a62565b67ffffffffffffffff169052565b612fdb60208601612a7f565b6001600160a01b0381166040840152506040850135606083015261300160608601612a62565b67ffffffffffffffff811660808401525061301e60808601612a7f565b6001600160a01b03811660a08401525060a085013560c083015261304460c08601612a62565b67ffffffffffffffff811660e08401525061306160e08601612a62565b6101006130798185018367ffffffffffffffff169052565b613084818801612a7f565b91505061012061309e818501836001600160a01b03169052565b6130a9818801612a7f565b9150506101406130c3818501836001600160a01b03169052565b6130ce818801612a7f565b9150506101606130e8818501836001600160a01b03169052565b6130f3818801612a7f565b91505061310c6101808401826001600160a01b03169052565b506001600160a01b0384166101a083015267ffffffffffffffff83166101c0830152610809565b634e487b7160e01b600052603260045260246000fd5b803563ffffffff81168114612a7a57600080fd5b60006020828403121561316f57600080fd5b6128a182613149565b600060001982141561318c5761318c612f52565b5060010190565b8183526000602080850194508260005b858110156131d05767ffffffffffffffff6131bd83612a62565b16875295820195908201906001016131a3565b509495945050505050565b6040815260006131ef604083018688613193565b8281036020848101919091528482528591810160005b8681101561322e5763ffffffff61321b85613149565b1682529282019290820190600101613205565b5098975050505050505050565b60008282101561324d5761324d612f52565b500390565b8183526000602080850194508260005b858110156131d0576001600160a01b0361327b83612a7f565b1687529582019590820190600101613262565b6040815260006132a2604083018688613193565b82810360208401526111ab818587613252565b60006001600160c01b0319808f60c01b1683526bffffffffffffffffffffffff198e60601b1660088401528c601c840152808c60c01b16603c84015250613310604483018b60601b6bffffffffffffffffffffffff19169052565b88605883015261332f607883018960c01b6001600160c01b0319169052565b613348608083018860c01b6001600160c01b0319169052565b613366608883018760601b6bffffffffffffffffffffffff19169052565b613384609c83018660601b6bffffffffffffffffffffffff19169052565b6133a260b083018560601b6bffffffffffffffffffffffff19169052565b6133c060c483018460601b6bffffffffffffffffffffffff19169052565b5060d8019c9b505050505050505050505050565b81835281816020850137506000828201602090810191909152601f909101601f19169091010190565b81835260007f07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff83111561342f57600080fd5b8260051b8083602087013760009401602001938452509192915050565b6101008152600061346261010083018b8d6133d4565b6001600160a01b03806134748c612a7f565b1660208501528061348760208d01612a7f565b1660408501525061349a60408b01612a62565b67ffffffffffffffff808216606086015260608c0135608086015284830360a086015282915089835260208301915060208a60051b8401018b60005b8c81101561354357858303601f19018552368e9003601e19018235126134fb57600080fd5b8d823501848135111561350d57600080fd5b803536038f131561351d57600080fd5b61352c848235602084016133d4565b6020968701969094509290920191506001016134d6565b505085810360c0870152613558818a8c613252565b935050505082810360e08401526135708185876133fd565b9c9b505050505050505050505050565b634e487b7160e01b600052600160045260246000fd5b6000602082840312156135a857600080fd5b815180151581146128a157600080fd5b60005b838110156135d35781810151838201526020016135bb565b838111156122dc5750506000910152565b600081518084526135fc8160208601602086016135b8565b601f01601f19169290920160200192915050565b6001600160a01b038416815267ffffffffffffffff8316602082015260606040820152600061080960608301846135e4565b600082516136548184602087016135b8565b9190910192915050565b6020815260006128a160208301846135e456fea2646970667358221220a3cb0fb4af3f0daecf5023e12e2abe187e98609b528d3c82906054589287938b64736f6c63430008090033",
}

// RfqABI is the input ABI used to generate the binding from.
// Deprecated: Use RfqMetaData.ABI instead.
var RfqABI = RfqMetaData.ABI

// RfqBin is the compiled bytecode used for deploying new contracts.
// Deprecated: Use RfqMetaData.Bin instead.
var RfqBin = RfqMetaData.Bin

// DeployRfq deploys a new Ethereum contract, binding an instance of Rfq to it.
func DeployRfq(auth *bind.TransactOpts, backend bind.ContractBackend, _messageBus common.Address) (common.Address, *types.Transaction, *Rfq, error) {
	parsed, err := RfqMetaData.GetAbi()
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	if parsed == nil {
		return common.Address{}, nil, nil, errors.New("GetABI returned nil")
	}

	address, tx, contract, err := bind.DeployContract(auth, *parsed, common.FromHex(RfqBin), backend, _messageBus)
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	return address, tx, &Rfq{RfqCaller: RfqCaller{contract: contract}, RfqTransactor: RfqTransactor{contract: contract}, RfqFilterer: RfqFilterer{contract: contract}}, nil
}

// Rfq is an auto generated Go binding around an Ethereum contract.
type Rfq struct {
	RfqCaller     // Read-only binding to the contract
	RfqTransactor // Write-only binding to the contract
	RfqFilterer   // Log filterer for contract events
}

// RfqCaller is an auto generated read-only Go binding around an Ethereum contract.
type RfqCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RfqTransactor is an auto generated write-only Go binding around an Ethereum contract.
type RfqTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RfqFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type RfqFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RfqSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type RfqSession struct {
	Contract     *Rfq              // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// RfqCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type RfqCallerSession struct {
	Contract *RfqCaller    // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts // Call options to use throughout this session
}

// RfqTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type RfqTransactorSession struct {
	Contract     *RfqTransactor    // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// RfqRaw is an auto generated low-level Go binding around an Ethereum contract.
type RfqRaw struct {
	Contract *Rfq // Generic contract binding to access the raw methods on
}

// RfqCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type RfqCallerRaw struct {
	Contract *RfqCaller // Generic read-only contract binding to access the raw methods on
}

// RfqTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type RfqTransactorRaw struct {
	Contract *RfqTransactor // Generic write-only contract binding to access the raw methods on
}

// NewRfq creates a new instance of Rfq, bound to a specific deployed contract.
func NewRfq(address common.Address, backend bind.ContractBackend) (*Rfq, error) {
	contract, err := bindRfq(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &Rfq{RfqCaller: RfqCaller{contract: contract}, RfqTransactor: RfqTransactor{contract: contract}, RfqFilterer: RfqFilterer{contract: contract}}, nil
}

// NewRfqCaller creates a new read-only instance of Rfq, bound to a specific deployed contract.
func NewRfqCaller(address common.Address, caller bind.ContractCaller) (*RfqCaller, error) {
	contract, err := bindRfq(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &RfqCaller{contract: contract}, nil
}

// NewRfqTransactor creates a new write-only instance of Rfq, bound to a specific deployed contract.
func NewRfqTransactor(address common.Address, transactor bind.ContractTransactor) (*RfqTransactor, error) {
	contract, err := bindRfq(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &RfqTransactor{contract: contract}, nil
}

// NewRfqFilterer creates a new log filterer instance of Rfq, bound to a specific deployed contract.
func NewRfqFilterer(address common.Address, filterer bind.ContractFilterer) (*RfqFilterer, error) {
	contract, err := bindRfq(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &RfqFilterer{contract: contract}, nil
}

// bindRfq binds a generic wrapper to an already deployed contract.
func bindRfq(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := abi.JSON(strings.NewReader(RfqABI))
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Rfq *RfqRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Rfq.Contract.RfqCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Rfq *RfqRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Rfq.Contract.RfqTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Rfq *RfqRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Rfq.Contract.RfqTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Rfq *RfqCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Rfq.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Rfq *RfqTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Rfq.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Rfq *RfqTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Rfq.Contract.contract.Transact(opts, method, params...)
}

// ExecutedQuotes is a free data retrieval call binding the contract method 0xaa2003ea.
//
// Solidity: function executedQuotes(bytes32 ) view returns(bool)
func (_Rfq *RfqCaller) ExecutedQuotes(opts *bind.CallOpts, arg0 [32]byte) (bool, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "executedQuotes", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ExecutedQuotes is a free data retrieval call binding the contract method 0xaa2003ea.
//
// Solidity: function executedQuotes(bytes32 ) view returns(bool)
func (_Rfq *RfqSession) ExecutedQuotes(arg0 [32]byte) (bool, error) {
	return _Rfq.Contract.ExecutedQuotes(&_Rfq.CallOpts, arg0)
}

// ExecutedQuotes is a free data retrieval call binding the contract method 0xaa2003ea.
//
// Solidity: function executedQuotes(bytes32 ) view returns(bool)
func (_Rfq *RfqCallerSession) ExecutedQuotes(arg0 [32]byte) (bool, error) {
	return _Rfq.Contract.ExecutedQuotes(&_Rfq.CallOpts, arg0)
}

// FeePercGlobal is a free data retrieval call binding the contract method 0x0bd930b4.
//
// Solidity: function feePercGlobal() view returns(uint32)
func (_Rfq *RfqCaller) FeePercGlobal(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "feePercGlobal")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// FeePercGlobal is a free data retrieval call binding the contract method 0x0bd930b4.
//
// Solidity: function feePercGlobal() view returns(uint32)
func (_Rfq *RfqSession) FeePercGlobal() (uint32, error) {
	return _Rfq.Contract.FeePercGlobal(&_Rfq.CallOpts)
}

// FeePercGlobal is a free data retrieval call binding the contract method 0x0bd930b4.
//
// Solidity: function feePercGlobal() view returns(uint32)
func (_Rfq *RfqCallerSession) FeePercGlobal() (uint32, error) {
	return _Rfq.Contract.FeePercGlobal(&_Rfq.CallOpts)
}

// FeePercOverride is a free data retrieval call binding the contract method 0x3e07d172.
//
// Solidity: function feePercOverride(uint64 ) view returns(uint32)
func (_Rfq *RfqCaller) FeePercOverride(opts *bind.CallOpts, arg0 uint64) (uint32, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "feePercOverride", arg0)

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// FeePercOverride is a free data retrieval call binding the contract method 0x3e07d172.
//
// Solidity: function feePercOverride(uint64 ) view returns(uint32)
func (_Rfq *RfqSession) FeePercOverride(arg0 uint64) (uint32, error) {
	return _Rfq.Contract.FeePercOverride(&_Rfq.CallOpts, arg0)
}

// FeePercOverride is a free data retrieval call binding the contract method 0x3e07d172.
//
// Solidity: function feePercOverride(uint64 ) view returns(uint32)
func (_Rfq *RfqCallerSession) FeePercOverride(arg0 uint64) (uint32, error) {
	return _Rfq.Contract.FeePercOverride(&_Rfq.CallOpts, arg0)
}

// GetQuoteHash is a free data retrieval call binding the contract method 0xfae3b92c.
//
// Solidity: function getQuoteHash((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote) pure returns(bytes32)
func (_Rfq *RfqCaller) GetQuoteHash(opts *bind.CallOpts, _quote RFQQuote) ([32]byte, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "getQuoteHash", _quote)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetQuoteHash is a free data retrieval call binding the contract method 0xfae3b92c.
//
// Solidity: function getQuoteHash((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote) pure returns(bytes32)
func (_Rfq *RfqSession) GetQuoteHash(_quote RFQQuote) ([32]byte, error) {
	return _Rfq.Contract.GetQuoteHash(&_Rfq.CallOpts, _quote)
}

// GetQuoteHash is a free data retrieval call binding the contract method 0xfae3b92c.
//
// Solidity: function getQuoteHash((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote) pure returns(bytes32)
func (_Rfq *RfqCallerSession) GetQuoteHash(_quote RFQQuote) ([32]byte, error) {
	return _Rfq.Contract.GetQuoteHash(&_Rfq.CallOpts, _quote)
}

// GetRFQFee is a free data retrieval call binding the contract method 0x089062fe.
//
// Solidity: function getRFQFee(uint64 _dstChainId, uint256 _amount) view returns(uint256)
func (_Rfq *RfqCaller) GetRFQFee(opts *bind.CallOpts, _dstChainId uint64, _amount *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "getRFQFee", _dstChainId, _amount)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetRFQFee is a free data retrieval call binding the contract method 0x089062fe.
//
// Solidity: function getRFQFee(uint64 _dstChainId, uint256 _amount) view returns(uint256)
func (_Rfq *RfqSession) GetRFQFee(_dstChainId uint64, _amount *big.Int) (*big.Int, error) {
	return _Rfq.Contract.GetRFQFee(&_Rfq.CallOpts, _dstChainId, _amount)
}

// GetRFQFee is a free data retrieval call binding the contract method 0x089062fe.
//
// Solidity: function getRFQFee(uint64 _dstChainId, uint256 _amount) view returns(uint256)
func (_Rfq *RfqCallerSession) GetRFQFee(_dstChainId uint64, _amount *big.Int) (*big.Int, error) {
	return _Rfq.Contract.GetRFQFee(&_Rfq.CallOpts, _dstChainId, _amount)
}

// IsPauser is a free data retrieval call binding the contract method 0x46fbf68e.
//
// Solidity: function isPauser(address account) view returns(bool)
func (_Rfq *RfqCaller) IsPauser(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "isPauser", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsPauser is a free data retrieval call binding the contract method 0x46fbf68e.
//
// Solidity: function isPauser(address account) view returns(bool)
func (_Rfq *RfqSession) IsPauser(account common.Address) (bool, error) {
	return _Rfq.Contract.IsPauser(&_Rfq.CallOpts, account)
}

// IsPauser is a free data retrieval call binding the contract method 0x46fbf68e.
//
// Solidity: function isPauser(address account) view returns(bool)
func (_Rfq *RfqCallerSession) IsPauser(account common.Address) (bool, error) {
	return _Rfq.Contract.IsPauser(&_Rfq.CallOpts, account)
}

// MessageBus is a free data retrieval call binding the contract method 0xa1a227fa.
//
// Solidity: function messageBus() view returns(address)
func (_Rfq *RfqCaller) MessageBus(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "messageBus")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MessageBus is a free data retrieval call binding the contract method 0xa1a227fa.
//
// Solidity: function messageBus() view returns(address)
func (_Rfq *RfqSession) MessageBus() (common.Address, error) {
	return _Rfq.Contract.MessageBus(&_Rfq.CallOpts)
}

// MessageBus is a free data retrieval call binding the contract method 0xa1a227fa.
//
// Solidity: function messageBus() view returns(address)
func (_Rfq *RfqCallerSession) MessageBus() (common.Address, error) {
	return _Rfq.Contract.MessageBus(&_Rfq.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Rfq *RfqCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Rfq *RfqSession) Owner() (common.Address, error) {
	return _Rfq.Contract.Owner(&_Rfq.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Rfq *RfqCallerSession) Owner() (common.Address, error) {
	return _Rfq.Contract.Owner(&_Rfq.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Rfq *RfqCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Rfq *RfqSession) Paused() (bool, error) {
	return _Rfq.Contract.Paused(&_Rfq.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Rfq *RfqCallerSession) Paused() (bool, error) {
	return _Rfq.Contract.Paused(&_Rfq.CallOpts)
}

// Pausers is a free data retrieval call binding the contract method 0x80f51c12.
//
// Solidity: function pausers(address ) view returns(bool)
func (_Rfq *RfqCaller) Pausers(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "pausers", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Pausers is a free data retrieval call binding the contract method 0x80f51c12.
//
// Solidity: function pausers(address ) view returns(bool)
func (_Rfq *RfqSession) Pausers(arg0 common.Address) (bool, error) {
	return _Rfq.Contract.Pausers(&_Rfq.CallOpts, arg0)
}

// Pausers is a free data retrieval call binding the contract method 0x80f51c12.
//
// Solidity: function pausers(address ) view returns(bool)
func (_Rfq *RfqCallerSession) Pausers(arg0 common.Address) (bool, error) {
	return _Rfq.Contract.Pausers(&_Rfq.CallOpts, arg0)
}

// Quotes is a free data retrieval call binding the contract method 0x25329eaf.
//
// Solidity: function quotes(bytes32 ) view returns(bool)
func (_Rfq *RfqCaller) Quotes(opts *bind.CallOpts, arg0 [32]byte) (bool, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "quotes", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Quotes is a free data retrieval call binding the contract method 0x25329eaf.
//
// Solidity: function quotes(bytes32 ) view returns(bool)
func (_Rfq *RfqSession) Quotes(arg0 [32]byte) (bool, error) {
	return _Rfq.Contract.Quotes(&_Rfq.CallOpts, arg0)
}

// Quotes is a free data retrieval call binding the contract method 0x25329eaf.
//
// Solidity: function quotes(bytes32 ) view returns(bool)
func (_Rfq *RfqCallerSession) Quotes(arg0 [32]byte) (bool, error) {
	return _Rfq.Contract.Quotes(&_Rfq.CallOpts, arg0)
}

// RemoteRfqContracts is a free data retrieval call binding the contract method 0xcc47e400.
//
// Solidity: function remoteRfqContracts(uint64 ) view returns(address)
func (_Rfq *RfqCaller) RemoteRfqContracts(opts *bind.CallOpts, arg0 uint64) (common.Address, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "remoteRfqContracts", arg0)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// RemoteRfqContracts is a free data retrieval call binding the contract method 0xcc47e400.
//
// Solidity: function remoteRfqContracts(uint64 ) view returns(address)
func (_Rfq *RfqSession) RemoteRfqContracts(arg0 uint64) (common.Address, error) {
	return _Rfq.Contract.RemoteRfqContracts(&_Rfq.CallOpts, arg0)
}

// RemoteRfqContracts is a free data retrieval call binding the contract method 0xcc47e400.
//
// Solidity: function remoteRfqContracts(uint64 ) view returns(address)
func (_Rfq *RfqCallerSession) RemoteRfqContracts(arg0 uint64) (common.Address, error) {
	return _Rfq.Contract.RemoteRfqContracts(&_Rfq.CallOpts, arg0)
}

// TreasuryAddr is a free data retrieval call binding the contract method 0x30d9a62a.
//
// Solidity: function treasuryAddr() view returns(address)
func (_Rfq *RfqCaller) TreasuryAddr(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "treasuryAddr")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TreasuryAddr is a free data retrieval call binding the contract method 0x30d9a62a.
//
// Solidity: function treasuryAddr() view returns(address)
func (_Rfq *RfqSession) TreasuryAddr() (common.Address, error) {
	return _Rfq.Contract.TreasuryAddr(&_Rfq.CallOpts)
}

// TreasuryAddr is a free data retrieval call binding the contract method 0x30d9a62a.
//
// Solidity: function treasuryAddr() view returns(address)
func (_Rfq *RfqCallerSession) TreasuryAddr() (common.Address, error) {
	return _Rfq.Contract.TreasuryAddr(&_Rfq.CallOpts)
}

// UnconsumedMsg is a free data retrieval call binding the contract method 0xdf1f64ef.
//
// Solidity: function unconsumedMsg(bytes32 ) view returns(bool)
func (_Rfq *RfqCaller) UnconsumedMsg(opts *bind.CallOpts, arg0 [32]byte) (bool, error) {
	var out []interface{}
	err := _Rfq.contract.Call(opts, &out, "unconsumedMsg", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// UnconsumedMsg is a free data retrieval call binding the contract method 0xdf1f64ef.
//
// Solidity: function unconsumedMsg(bytes32 ) view returns(bool)
func (_Rfq *RfqSession) UnconsumedMsg(arg0 [32]byte) (bool, error) {
	return _Rfq.Contract.UnconsumedMsg(&_Rfq.CallOpts, arg0)
}

// UnconsumedMsg is a free data retrieval call binding the contract method 0xdf1f64ef.
//
// Solidity: function unconsumedMsg(bytes32 ) view returns(bool)
func (_Rfq *RfqCallerSession) UnconsumedMsg(arg0 [32]byte) (bool, error) {
	return _Rfq.Contract.UnconsumedMsg(&_Rfq.CallOpts, arg0)
}

// AddPauser is a paid mutator transaction binding the contract method 0x82dc1ec4.
//
// Solidity: function addPauser(address account) returns()
func (_Rfq *RfqTransactor) AddPauser(opts *bind.TransactOpts, account common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "addPauser", account)
}

// AddPauser is a paid mutator transaction binding the contract method 0x82dc1ec4.
//
// Solidity: function addPauser(address account) returns()
func (_Rfq *RfqSession) AddPauser(account common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.AddPauser(&_Rfq.TransactOpts, account)
}

// AddPauser is a paid mutator transaction binding the contract method 0x82dc1ec4.
//
// Solidity: function addPauser(address account) returns()
func (_Rfq *RfqTransactorSession) AddPauser(account common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.AddPauser(&_Rfq.TransactOpts, account)
}

// CollectFee is a paid mutator transaction binding the contract method 0x2ec0ff6c.
//
// Solidity: function collectFee(address _token, uint256 _amount) returns()
func (_Rfq *RfqTransactor) CollectFee(opts *bind.TransactOpts, _token common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "collectFee", _token, _amount)
}

// CollectFee is a paid mutator transaction binding the contract method 0x2ec0ff6c.
//
// Solidity: function collectFee(address _token, uint256 _amount) returns()
func (_Rfq *RfqSession) CollectFee(_token common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _Rfq.Contract.CollectFee(&_Rfq.TransactOpts, _token, _amount)
}

// CollectFee is a paid mutator transaction binding the contract method 0x2ec0ff6c.
//
// Solidity: function collectFee(address _token, uint256 _amount) returns()
func (_Rfq *RfqTransactorSession) CollectFee(_token common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _Rfq.Contract.CollectFee(&_Rfq.TransactOpts, _token, _amount)
}

// DstTransfer is a paid mutator transaction binding the contract method 0x5bf9f32b.
//
// Solidity: function dstTransfer((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote) payable returns()
func (_Rfq *RfqTransactor) DstTransfer(opts *bind.TransactOpts, _quote RFQQuote) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "dstTransfer", _quote)
}

// DstTransfer is a paid mutator transaction binding the contract method 0x5bf9f32b.
//
// Solidity: function dstTransfer((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote) payable returns()
func (_Rfq *RfqSession) DstTransfer(_quote RFQQuote) (*types.Transaction, error) {
	return _Rfq.Contract.DstTransfer(&_Rfq.TransactOpts, _quote)
}

// DstTransfer is a paid mutator transaction binding the contract method 0x5bf9f32b.
//
// Solidity: function dstTransfer((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote) payable returns()
func (_Rfq *RfqTransactorSession) DstTransfer(_quote RFQQuote) (*types.Transaction, error) {
	return _Rfq.Contract.DstTransfer(&_Rfq.TransactOpts, _quote)
}

// ExecuteMessage is a paid mutator transaction binding the contract method 0x063ce4e5.
//
// Solidity: function executeMessage(bytes _sender, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqTransactor) ExecuteMessage(opts *bind.TransactOpts, _sender []byte, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "executeMessage", _sender, _srcChainId, _message, _executor)
}

// ExecuteMessage is a paid mutator transaction binding the contract method 0x063ce4e5.
//
// Solidity: function executeMessage(bytes _sender, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqSession) ExecuteMessage(_sender []byte, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessage(&_Rfq.TransactOpts, _sender, _srcChainId, _message, _executor)
}

// ExecuteMessage is a paid mutator transaction binding the contract method 0x063ce4e5.
//
// Solidity: function executeMessage(bytes _sender, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqTransactorSession) ExecuteMessage(_sender []byte, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessage(&_Rfq.TransactOpts, _sender, _srcChainId, _message, _executor)
}

// ExecuteMessage0 is a paid mutator transaction binding the contract method 0x9c649fdf.
//
// Solidity: function executeMessage(address _sender, uint64 _srcChainId, bytes _message, address ) payable returns(uint8)
func (_Rfq *RfqTransactor) ExecuteMessage0(opts *bind.TransactOpts, _sender common.Address, _srcChainId uint64, _message []byte, arg3 common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "executeMessage0", _sender, _srcChainId, _message, arg3)
}

// ExecuteMessage0 is a paid mutator transaction binding the contract method 0x9c649fdf.
//
// Solidity: function executeMessage(address _sender, uint64 _srcChainId, bytes _message, address ) payable returns(uint8)
func (_Rfq *RfqSession) ExecuteMessage0(_sender common.Address, _srcChainId uint64, _message []byte, arg3 common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessage0(&_Rfq.TransactOpts, _sender, _srcChainId, _message, arg3)
}

// ExecuteMessage0 is a paid mutator transaction binding the contract method 0x9c649fdf.
//
// Solidity: function executeMessage(address _sender, uint64 _srcChainId, bytes _message, address ) payable returns(uint8)
func (_Rfq *RfqTransactorSession) ExecuteMessage0(_sender common.Address, _srcChainId uint64, _message []byte, arg3 common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessage0(&_Rfq.TransactOpts, _sender, _srcChainId, _message, arg3)
}

// ExecuteMessageWithTransfer is a paid mutator transaction binding the contract method 0x7cd2bffc.
//
// Solidity: function executeMessageWithTransfer(address _sender, address _token, uint256 _amount, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqTransactor) ExecuteMessageWithTransfer(opts *bind.TransactOpts, _sender common.Address, _token common.Address, _amount *big.Int, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "executeMessageWithTransfer", _sender, _token, _amount, _srcChainId, _message, _executor)
}

// ExecuteMessageWithTransfer is a paid mutator transaction binding the contract method 0x7cd2bffc.
//
// Solidity: function executeMessageWithTransfer(address _sender, address _token, uint256 _amount, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqSession) ExecuteMessageWithTransfer(_sender common.Address, _token common.Address, _amount *big.Int, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessageWithTransfer(&_Rfq.TransactOpts, _sender, _token, _amount, _srcChainId, _message, _executor)
}

// ExecuteMessageWithTransfer is a paid mutator transaction binding the contract method 0x7cd2bffc.
//
// Solidity: function executeMessageWithTransfer(address _sender, address _token, uint256 _amount, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqTransactorSession) ExecuteMessageWithTransfer(_sender common.Address, _token common.Address, _amount *big.Int, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessageWithTransfer(&_Rfq.TransactOpts, _sender, _token, _amount, _srcChainId, _message, _executor)
}

// ExecuteMessageWithTransferFallback is a paid mutator transaction binding the contract method 0x5ab7afc6.
//
// Solidity: function executeMessageWithTransferFallback(address _sender, address _token, uint256 _amount, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqTransactor) ExecuteMessageWithTransferFallback(opts *bind.TransactOpts, _sender common.Address, _token common.Address, _amount *big.Int, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "executeMessageWithTransferFallback", _sender, _token, _amount, _srcChainId, _message, _executor)
}

// ExecuteMessageWithTransferFallback is a paid mutator transaction binding the contract method 0x5ab7afc6.
//
// Solidity: function executeMessageWithTransferFallback(address _sender, address _token, uint256 _amount, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqSession) ExecuteMessageWithTransferFallback(_sender common.Address, _token common.Address, _amount *big.Int, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessageWithTransferFallback(&_Rfq.TransactOpts, _sender, _token, _amount, _srcChainId, _message, _executor)
}

// ExecuteMessageWithTransferFallback is a paid mutator transaction binding the contract method 0x5ab7afc6.
//
// Solidity: function executeMessageWithTransferFallback(address _sender, address _token, uint256 _amount, uint64 _srcChainId, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqTransactorSession) ExecuteMessageWithTransferFallback(_sender common.Address, _token common.Address, _amount *big.Int, _srcChainId uint64, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessageWithTransferFallback(&_Rfq.TransactOpts, _sender, _token, _amount, _srcChainId, _message, _executor)
}

// ExecuteMessageWithTransferRefund is a paid mutator transaction binding the contract method 0x0bcb4982.
//
// Solidity: function executeMessageWithTransferRefund(address _token, uint256 _amount, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqTransactor) ExecuteMessageWithTransferRefund(opts *bind.TransactOpts, _token common.Address, _amount *big.Int, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "executeMessageWithTransferRefund", _token, _amount, _message, _executor)
}

// ExecuteMessageWithTransferRefund is a paid mutator transaction binding the contract method 0x0bcb4982.
//
// Solidity: function executeMessageWithTransferRefund(address _token, uint256 _amount, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqSession) ExecuteMessageWithTransferRefund(_token common.Address, _amount *big.Int, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessageWithTransferRefund(&_Rfq.TransactOpts, _token, _amount, _message, _executor)
}

// ExecuteMessageWithTransferRefund is a paid mutator transaction binding the contract method 0x0bcb4982.
//
// Solidity: function executeMessageWithTransferRefund(address _token, uint256 _amount, bytes _message, address _executor) payable returns(uint8)
func (_Rfq *RfqTransactorSession) ExecuteMessageWithTransferRefund(_token common.Address, _amount *big.Int, _message []byte, _executor common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteMessageWithTransferRefund(&_Rfq.TransactOpts, _token, _amount, _message, _executor)
}

// ExecuteRefund is a paid mutator transaction binding the contract method 0x3e73b92c.
//
// Solidity: function executeRefund((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) returns()
func (_Rfq *RfqTransactor) ExecuteRefund(opts *bind.TransactOpts, _quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "executeRefund", _quote, _message, _route, _sigs, _signers, _powers)
}

// ExecuteRefund is a paid mutator transaction binding the contract method 0x3e73b92c.
//
// Solidity: function executeRefund((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) returns()
func (_Rfq *RfqSession) ExecuteRefund(_quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteRefund(&_Rfq.TransactOpts, _quote, _message, _route, _sigs, _signers, _powers)
}

// ExecuteRefund is a paid mutator transaction binding the contract method 0x3e73b92c.
//
// Solidity: function executeRefund((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) returns()
func (_Rfq *RfqTransactorSession) ExecuteRefund(_quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.Contract.ExecuteRefund(&_Rfq.TransactOpts, _quote, _message, _route, _sigs, _signers, _powers)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Rfq *RfqTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Rfq *RfqSession) Pause() (*types.Transaction, error) {
	return _Rfq.Contract.Pause(&_Rfq.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Rfq *RfqTransactorSession) Pause() (*types.Transaction, error) {
	return _Rfq.Contract.Pause(&_Rfq.TransactOpts)
}

// RemovePauser is a paid mutator transaction binding the contract method 0x6b2c0f55.
//
// Solidity: function removePauser(address account) returns()
func (_Rfq *RfqTransactor) RemovePauser(opts *bind.TransactOpts, account common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "removePauser", account)
}

// RemovePauser is a paid mutator transaction binding the contract method 0x6b2c0f55.
//
// Solidity: function removePauser(address account) returns()
func (_Rfq *RfqSession) RemovePauser(account common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.RemovePauser(&_Rfq.TransactOpts, account)
}

// RemovePauser is a paid mutator transaction binding the contract method 0x6b2c0f55.
//
// Solidity: function removePauser(address account) returns()
func (_Rfq *RfqTransactorSession) RemovePauser(account common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.RemovePauser(&_Rfq.TransactOpts, account)
}

// RenouncePauser is a paid mutator transaction binding the contract method 0x6ef8d66d.
//
// Solidity: function renouncePauser() returns()
func (_Rfq *RfqTransactor) RenouncePauser(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "renouncePauser")
}

// RenouncePauser is a paid mutator transaction binding the contract method 0x6ef8d66d.
//
// Solidity: function renouncePauser() returns()
func (_Rfq *RfqSession) RenouncePauser() (*types.Transaction, error) {
	return _Rfq.Contract.RenouncePauser(&_Rfq.TransactOpts)
}

// RenouncePauser is a paid mutator transaction binding the contract method 0x6ef8d66d.
//
// Solidity: function renouncePauser() returns()
func (_Rfq *RfqTransactorSession) RenouncePauser() (*types.Transaction, error) {
	return _Rfq.Contract.RenouncePauser(&_Rfq.TransactOpts)
}

// RequestRefund is a paid mutator transaction binding the contract method 0xd129153c.
//
// Solidity: function requestRefund((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) payable returns()
func (_Rfq *RfqTransactor) RequestRefund(opts *bind.TransactOpts, _quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "requestRefund", _quote, _message, _route, _sigs, _signers, _powers)
}

// RequestRefund is a paid mutator transaction binding the contract method 0xd129153c.
//
// Solidity: function requestRefund((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) payable returns()
func (_Rfq *RfqSession) RequestRefund(_quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.Contract.RequestRefund(&_Rfq.TransactOpts, _quote, _message, _route, _sigs, _signers, _powers)
}

// RequestRefund is a paid mutator transaction binding the contract method 0xd129153c.
//
// Solidity: function requestRefund((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) payable returns()
func (_Rfq *RfqTransactorSession) RequestRefund(_quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.Contract.RequestRefund(&_Rfq.TransactOpts, _quote, _message, _route, _sigs, _signers, _powers)
}

// SetFeePerc is a paid mutator transaction binding the contract method 0xab9341fd.
//
// Solidity: function setFeePerc(uint64[] _chainIds, uint32[] _feePercs) returns()
func (_Rfq *RfqTransactor) SetFeePerc(opts *bind.TransactOpts, _chainIds []uint64, _feePercs []uint32) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "setFeePerc", _chainIds, _feePercs)
}

// SetFeePerc is a paid mutator transaction binding the contract method 0xab9341fd.
//
// Solidity: function setFeePerc(uint64[] _chainIds, uint32[] _feePercs) returns()
func (_Rfq *RfqSession) SetFeePerc(_chainIds []uint64, _feePercs []uint32) (*types.Transaction, error) {
	return _Rfq.Contract.SetFeePerc(&_Rfq.TransactOpts, _chainIds, _feePercs)
}

// SetFeePerc is a paid mutator transaction binding the contract method 0xab9341fd.
//
// Solidity: function setFeePerc(uint64[] _chainIds, uint32[] _feePercs) returns()
func (_Rfq *RfqTransactorSession) SetFeePerc(_chainIds []uint64, _feePercs []uint32) (*types.Transaction, error) {
	return _Rfq.Contract.SetFeePerc(&_Rfq.TransactOpts, _chainIds, _feePercs)
}

// SetMessageBus is a paid mutator transaction binding the contract method 0x547cad12.
//
// Solidity: function setMessageBus(address _messageBus) returns()
func (_Rfq *RfqTransactor) SetMessageBus(opts *bind.TransactOpts, _messageBus common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "setMessageBus", _messageBus)
}

// SetMessageBus is a paid mutator transaction binding the contract method 0x547cad12.
//
// Solidity: function setMessageBus(address _messageBus) returns()
func (_Rfq *RfqSession) SetMessageBus(_messageBus common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.SetMessageBus(&_Rfq.TransactOpts, _messageBus)
}

// SetMessageBus is a paid mutator transaction binding the contract method 0x547cad12.
//
// Solidity: function setMessageBus(address _messageBus) returns()
func (_Rfq *RfqTransactorSession) SetMessageBus(_messageBus common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.SetMessageBus(&_Rfq.TransactOpts, _messageBus)
}

// SetRemoteRfqContracts is a paid mutator transaction binding the contract method 0xcbac44df.
//
// Solidity: function setRemoteRfqContracts(uint64[] _chainIds, address[] _remoteRfqContracts) returns()
func (_Rfq *RfqTransactor) SetRemoteRfqContracts(opts *bind.TransactOpts, _chainIds []uint64, _remoteRfqContracts []common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "setRemoteRfqContracts", _chainIds, _remoteRfqContracts)
}

// SetRemoteRfqContracts is a paid mutator transaction binding the contract method 0xcbac44df.
//
// Solidity: function setRemoteRfqContracts(uint64[] _chainIds, address[] _remoteRfqContracts) returns()
func (_Rfq *RfqSession) SetRemoteRfqContracts(_chainIds []uint64, _remoteRfqContracts []common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.SetRemoteRfqContracts(&_Rfq.TransactOpts, _chainIds, _remoteRfqContracts)
}

// SetRemoteRfqContracts is a paid mutator transaction binding the contract method 0xcbac44df.
//
// Solidity: function setRemoteRfqContracts(uint64[] _chainIds, address[] _remoteRfqContracts) returns()
func (_Rfq *RfqTransactorSession) SetRemoteRfqContracts(_chainIds []uint64, _remoteRfqContracts []common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.SetRemoteRfqContracts(&_Rfq.TransactOpts, _chainIds, _remoteRfqContracts)
}

// SetTreasuryAddr is a paid mutator transaction binding the contract method 0xa7e05b9c.
//
// Solidity: function setTreasuryAddr(address _treasuryAddr) returns()
func (_Rfq *RfqTransactor) SetTreasuryAddr(opts *bind.TransactOpts, _treasuryAddr common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "setTreasuryAddr", _treasuryAddr)
}

// SetTreasuryAddr is a paid mutator transaction binding the contract method 0xa7e05b9c.
//
// Solidity: function setTreasuryAddr(address _treasuryAddr) returns()
func (_Rfq *RfqSession) SetTreasuryAddr(_treasuryAddr common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.SetTreasuryAddr(&_Rfq.TransactOpts, _treasuryAddr)
}

// SetTreasuryAddr is a paid mutator transaction binding the contract method 0xa7e05b9c.
//
// Solidity: function setTreasuryAddr(address _treasuryAddr) returns()
func (_Rfq *RfqTransactorSession) SetTreasuryAddr(_treasuryAddr common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.SetTreasuryAddr(&_Rfq.TransactOpts, _treasuryAddr)
}

// SrcDeposit is a paid mutator transaction binding the contract method 0x2ca79b4d.
//
// Solidity: function srcDeposit((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, uint64 _submissionDeadline) payable returns(bytes32)
func (_Rfq *RfqTransactor) SrcDeposit(opts *bind.TransactOpts, _quote RFQQuote, _submissionDeadline uint64) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "srcDeposit", _quote, _submissionDeadline)
}

// SrcDeposit is a paid mutator transaction binding the contract method 0x2ca79b4d.
//
// Solidity: function srcDeposit((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, uint64 _submissionDeadline) payable returns(bytes32)
func (_Rfq *RfqSession) SrcDeposit(_quote RFQQuote, _submissionDeadline uint64) (*types.Transaction, error) {
	return _Rfq.Contract.SrcDeposit(&_Rfq.TransactOpts, _quote, _submissionDeadline)
}

// SrcDeposit is a paid mutator transaction binding the contract method 0x2ca79b4d.
//
// Solidity: function srcDeposit((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, uint64 _submissionDeadline) payable returns(bytes32)
func (_Rfq *RfqTransactorSession) SrcDeposit(_quote RFQQuote, _submissionDeadline uint64) (*types.Transaction, error) {
	return _Rfq.Contract.SrcDeposit(&_Rfq.TransactOpts, _quote, _submissionDeadline)
}

// SrcRelease is a paid mutator transaction binding the contract method 0xabd23f8b.
//
// Solidity: function srcRelease((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) returns()
func (_Rfq *RfqTransactor) SrcRelease(opts *bind.TransactOpts, _quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "srcRelease", _quote, _message, _route, _sigs, _signers, _powers)
}

// SrcRelease is a paid mutator transaction binding the contract method 0xabd23f8b.
//
// Solidity: function srcRelease((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) returns()
func (_Rfq *RfqSession) SrcRelease(_quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.Contract.SrcRelease(&_Rfq.TransactOpts, _quote, _message, _route, _sigs, _signers, _powers)
}

// SrcRelease is a paid mutator transaction binding the contract method 0xabd23f8b.
//
// Solidity: function srcRelease((uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) _quote, bytes _message, (address,address,uint64,bytes32) _route, bytes[] _sigs, address[] _signers, uint256[] _powers) returns()
func (_Rfq *RfqTransactorSession) SrcRelease(_quote RFQQuote, _message []byte, _route MsgDataTypesRouteInfo, _sigs [][]byte, _signers []common.Address, _powers []*big.Int) (*types.Transaction, error) {
	return _Rfq.Contract.SrcRelease(&_Rfq.TransactOpts, _quote, _message, _route, _sigs, _signers, _powers)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Rfq *RfqTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Rfq *RfqSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.TransferOwnership(&_Rfq.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Rfq *RfqTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Rfq.Contract.TransferOwnership(&_Rfq.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Rfq *RfqTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Rfq.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Rfq *RfqSession) Unpause() (*types.Transaction, error) {
	return _Rfq.Contract.Unpause(&_Rfq.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Rfq *RfqTransactorSession) Unpause() (*types.Transaction, error) {
	return _Rfq.Contract.Unpause(&_Rfq.TransactOpts)
}

// RfqDstTransferredIterator is returned from FilterDstTransferred and is used to iterate over the raw logs and unpacked data for DstTransferred events raised by the Rfq contract.
type RfqDstTransferredIterator struct {
	Event *RfqDstTransferred // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqDstTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqDstTransferred)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqDstTransferred)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqDstTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqDstTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqDstTransferred represents a DstTransferred event raised by the Rfq contract.
type RfqDstTransferred struct {
	Hash [32]byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterDstTransferred is a free log retrieval operation binding the contract event 0x3e9151a84654790f7b6b716dd4e3ff3f520fc83caa56d52a28f0b98f81c7e778.
//
// Solidity: event DstTransferred(bytes32 hash)
func (_Rfq *RfqFilterer) FilterDstTransferred(opts *bind.FilterOpts) (*RfqDstTransferredIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "DstTransferred")
	if err != nil {
		return nil, err
	}
	return &RfqDstTransferredIterator{contract: _Rfq.contract, event: "DstTransferred", logs: logs, sub: sub}, nil
}

// WatchDstTransferred is a free log subscription operation binding the contract event 0x3e9151a84654790f7b6b716dd4e3ff3f520fc83caa56d52a28f0b98f81c7e778.
//
// Solidity: event DstTransferred(bytes32 hash)
func (_Rfq *RfqFilterer) WatchDstTransferred(opts *bind.WatchOpts, sink chan<- *RfqDstTransferred) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "DstTransferred")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqDstTransferred)
				if err := _Rfq.contract.UnpackLog(event, "DstTransferred", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseDstTransferred is a log parse operation binding the contract event 0x3e9151a84654790f7b6b716dd4e3ff3f520fc83caa56d52a28f0b98f81c7e778.
//
// Solidity: event DstTransferred(bytes32 hash)
func (_Rfq *RfqFilterer) ParseDstTransferred(log types.Log) (*RfqDstTransferred, error) {
	event := new(RfqDstTransferred)
	if err := _Rfq.contract.UnpackLog(event, "DstTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqFeeCollectedIterator is returned from FilterFeeCollected and is used to iterate over the raw logs and unpacked data for FeeCollected events raised by the Rfq contract.
type RfqFeeCollectedIterator struct {
	Event *RfqFeeCollected // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqFeeCollectedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqFeeCollected)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqFeeCollected)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqFeeCollectedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqFeeCollectedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqFeeCollected represents a FeeCollected event raised by the Rfq contract.
type RfqFeeCollected struct {
	TreasuryAddr common.Address
	Token        common.Address
	Amount       *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterFeeCollected is a free log retrieval operation binding the contract event 0xf228de527fc1b9843baac03b9a04565473a263375950e63435d4138464386f46.
//
// Solidity: event FeeCollected(address treasuryAddr, address token, uint256 amount)
func (_Rfq *RfqFilterer) FilterFeeCollected(opts *bind.FilterOpts) (*RfqFeeCollectedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "FeeCollected")
	if err != nil {
		return nil, err
	}
	return &RfqFeeCollectedIterator{contract: _Rfq.contract, event: "FeeCollected", logs: logs, sub: sub}, nil
}

// WatchFeeCollected is a free log subscription operation binding the contract event 0xf228de527fc1b9843baac03b9a04565473a263375950e63435d4138464386f46.
//
// Solidity: event FeeCollected(address treasuryAddr, address token, uint256 amount)
func (_Rfq *RfqFilterer) WatchFeeCollected(opts *bind.WatchOpts, sink chan<- *RfqFeeCollected) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "FeeCollected")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqFeeCollected)
				if err := _Rfq.contract.UnpackLog(event, "FeeCollected", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseFeeCollected is a log parse operation binding the contract event 0xf228de527fc1b9843baac03b9a04565473a263375950e63435d4138464386f46.
//
// Solidity: event FeeCollected(address treasuryAddr, address token, uint256 amount)
func (_Rfq *RfqFilterer) ParseFeeCollected(log types.Log) (*RfqFeeCollected, error) {
	event := new(RfqFeeCollected)
	if err := _Rfq.contract.UnpackLog(event, "FeeCollected", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqFeePercUpdatedIterator is returned from FilterFeePercUpdated and is used to iterate over the raw logs and unpacked data for FeePercUpdated events raised by the Rfq contract.
type RfqFeePercUpdatedIterator struct {
	Event *RfqFeePercUpdated // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqFeePercUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqFeePercUpdated)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqFeePercUpdated)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqFeePercUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqFeePercUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqFeePercUpdated represents a FeePercUpdated event raised by the Rfq contract.
type RfqFeePercUpdated struct {
	ChainIds []uint64
	FeePercs []uint32
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterFeePercUpdated is a free log retrieval operation binding the contract event 0x541df5e570cf10ffe04899eebd9eebebd1c54e2bd4af9f24b23fb4a40c6ea00b.
//
// Solidity: event FeePercUpdated(uint64[] chainIds, uint32[] feePercs)
func (_Rfq *RfqFilterer) FilterFeePercUpdated(opts *bind.FilterOpts) (*RfqFeePercUpdatedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "FeePercUpdated")
	if err != nil {
		return nil, err
	}
	return &RfqFeePercUpdatedIterator{contract: _Rfq.contract, event: "FeePercUpdated", logs: logs, sub: sub}, nil
}

// WatchFeePercUpdated is a free log subscription operation binding the contract event 0x541df5e570cf10ffe04899eebd9eebebd1c54e2bd4af9f24b23fb4a40c6ea00b.
//
// Solidity: event FeePercUpdated(uint64[] chainIds, uint32[] feePercs)
func (_Rfq *RfqFilterer) WatchFeePercUpdated(opts *bind.WatchOpts, sink chan<- *RfqFeePercUpdated) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "FeePercUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqFeePercUpdated)
				if err := _Rfq.contract.UnpackLog(event, "FeePercUpdated", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseFeePercUpdated is a log parse operation binding the contract event 0x541df5e570cf10ffe04899eebd9eebebd1c54e2bd4af9f24b23fb4a40c6ea00b.
//
// Solidity: event FeePercUpdated(uint64[] chainIds, uint32[] feePercs)
func (_Rfq *RfqFilterer) ParseFeePercUpdated(log types.Log) (*RfqFeePercUpdated, error) {
	event := new(RfqFeePercUpdated)
	if err := _Rfq.contract.UnpackLog(event, "FeePercUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqMessageBusUpdatedIterator is returned from FilterMessageBusUpdated and is used to iterate over the raw logs and unpacked data for MessageBusUpdated events raised by the Rfq contract.
type RfqMessageBusUpdatedIterator struct {
	Event *RfqMessageBusUpdated // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqMessageBusUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqMessageBusUpdated)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqMessageBusUpdated)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqMessageBusUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqMessageBusUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqMessageBusUpdated represents a MessageBusUpdated event raised by the Rfq contract.
type RfqMessageBusUpdated struct {
	MessageBus common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterMessageBusUpdated is a free log retrieval operation binding the contract event 0x3f8223bcd8b3b875473e9f9e14e1ad075451a2b5ffd31591655da9a01516bf5e.
//
// Solidity: event MessageBusUpdated(address messageBus)
func (_Rfq *RfqFilterer) FilterMessageBusUpdated(opts *bind.FilterOpts) (*RfqMessageBusUpdatedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "MessageBusUpdated")
	if err != nil {
		return nil, err
	}
	return &RfqMessageBusUpdatedIterator{contract: _Rfq.contract, event: "MessageBusUpdated", logs: logs, sub: sub}, nil
}

// WatchMessageBusUpdated is a free log subscription operation binding the contract event 0x3f8223bcd8b3b875473e9f9e14e1ad075451a2b5ffd31591655da9a01516bf5e.
//
// Solidity: event MessageBusUpdated(address messageBus)
func (_Rfq *RfqFilterer) WatchMessageBusUpdated(opts *bind.WatchOpts, sink chan<- *RfqMessageBusUpdated) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "MessageBusUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqMessageBusUpdated)
				if err := _Rfq.contract.UnpackLog(event, "MessageBusUpdated", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseMessageBusUpdated is a log parse operation binding the contract event 0x3f8223bcd8b3b875473e9f9e14e1ad075451a2b5ffd31591655da9a01516bf5e.
//
// Solidity: event MessageBusUpdated(address messageBus)
func (_Rfq *RfqFilterer) ParseMessageBusUpdated(log types.Log) (*RfqMessageBusUpdated, error) {
	event := new(RfqMessageBusUpdated)
	if err := _Rfq.contract.UnpackLog(event, "MessageBusUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqMessageReceivedIterator is returned from FilterMessageReceived and is used to iterate over the raw logs and unpacked data for MessageReceived events raised by the Rfq contract.
type RfqMessageReceivedIterator struct {
	Event *RfqMessageReceived // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqMessageReceivedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqMessageReceived)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqMessageReceived)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqMessageReceivedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqMessageReceivedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqMessageReceived represents a MessageReceived event raised by the Rfq contract.
type RfqMessageReceived struct {
	Hash [32]byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterMessageReceived is a free log retrieval operation binding the contract event 0xe29dc34207c78fc0f6048a32f159139c33339c6d6df8b07dcd33f6d699ff2327.
//
// Solidity: event MessageReceived(bytes32 hash)
func (_Rfq *RfqFilterer) FilterMessageReceived(opts *bind.FilterOpts) (*RfqMessageReceivedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "MessageReceived")
	if err != nil {
		return nil, err
	}
	return &RfqMessageReceivedIterator{contract: _Rfq.contract, event: "MessageReceived", logs: logs, sub: sub}, nil
}

// WatchMessageReceived is a free log subscription operation binding the contract event 0xe29dc34207c78fc0f6048a32f159139c33339c6d6df8b07dcd33f6d699ff2327.
//
// Solidity: event MessageReceived(bytes32 hash)
func (_Rfq *RfqFilterer) WatchMessageReceived(opts *bind.WatchOpts, sink chan<- *RfqMessageReceived) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "MessageReceived")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqMessageReceived)
				if err := _Rfq.contract.UnpackLog(event, "MessageReceived", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseMessageReceived is a log parse operation binding the contract event 0xe29dc34207c78fc0f6048a32f159139c33339c6d6df8b07dcd33f6d699ff2327.
//
// Solidity: event MessageReceived(bytes32 hash)
func (_Rfq *RfqFilterer) ParseMessageReceived(log types.Log) (*RfqMessageReceived, error) {
	event := new(RfqMessageReceived)
	if err := _Rfq.contract.UnpackLog(event, "MessageReceived", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the Rfq contract.
type RfqOwnershipTransferredIterator struct {
	Event *RfqOwnershipTransferred // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqOwnershipTransferred)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqOwnershipTransferred)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqOwnershipTransferred represents a OwnershipTransferred event raised by the Rfq contract.
type RfqOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Rfq *RfqFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*RfqOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &RfqOwnershipTransferredIterator{contract: _Rfq.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Rfq *RfqFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *RfqOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqOwnershipTransferred)
				if err := _Rfq.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Rfq *RfqFilterer) ParseOwnershipTransferred(log types.Log) (*RfqOwnershipTransferred, error) {
	event := new(RfqOwnershipTransferred)
	if err := _Rfq.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the Rfq contract.
type RfqPausedIterator struct {
	Event *RfqPaused // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqPaused)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqPaused)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqPaused represents a Paused event raised by the Rfq contract.
type RfqPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Rfq *RfqFilterer) FilterPaused(opts *bind.FilterOpts) (*RfqPausedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &RfqPausedIterator{contract: _Rfq.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Rfq *RfqFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *RfqPaused) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqPaused)
				if err := _Rfq.contract.UnpackLog(event, "Paused", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParsePaused is a log parse operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Rfq *RfqFilterer) ParsePaused(log types.Log) (*RfqPaused, error) {
	event := new(RfqPaused)
	if err := _Rfq.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqPauserAddedIterator is returned from FilterPauserAdded and is used to iterate over the raw logs and unpacked data for PauserAdded events raised by the Rfq contract.
type RfqPauserAddedIterator struct {
	Event *RfqPauserAdded // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqPauserAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqPauserAdded)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqPauserAdded)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqPauserAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqPauserAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqPauserAdded represents a PauserAdded event raised by the Rfq contract.
type RfqPauserAdded struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPauserAdded is a free log retrieval operation binding the contract event 0x6719d08c1888103bea251a4ed56406bd0c3e69723c8a1686e017e7bbe159b6f8.
//
// Solidity: event PauserAdded(address account)
func (_Rfq *RfqFilterer) FilterPauserAdded(opts *bind.FilterOpts) (*RfqPauserAddedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "PauserAdded")
	if err != nil {
		return nil, err
	}
	return &RfqPauserAddedIterator{contract: _Rfq.contract, event: "PauserAdded", logs: logs, sub: sub}, nil
}

// WatchPauserAdded is a free log subscription operation binding the contract event 0x6719d08c1888103bea251a4ed56406bd0c3e69723c8a1686e017e7bbe159b6f8.
//
// Solidity: event PauserAdded(address account)
func (_Rfq *RfqFilterer) WatchPauserAdded(opts *bind.WatchOpts, sink chan<- *RfqPauserAdded) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "PauserAdded")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqPauserAdded)
				if err := _Rfq.contract.UnpackLog(event, "PauserAdded", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParsePauserAdded is a log parse operation binding the contract event 0x6719d08c1888103bea251a4ed56406bd0c3e69723c8a1686e017e7bbe159b6f8.
//
// Solidity: event PauserAdded(address account)
func (_Rfq *RfqFilterer) ParsePauserAdded(log types.Log) (*RfqPauserAdded, error) {
	event := new(RfqPauserAdded)
	if err := _Rfq.contract.UnpackLog(event, "PauserAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqPauserRemovedIterator is returned from FilterPauserRemoved and is used to iterate over the raw logs and unpacked data for PauserRemoved events raised by the Rfq contract.
type RfqPauserRemovedIterator struct {
	Event *RfqPauserRemoved // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqPauserRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqPauserRemoved)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqPauserRemoved)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqPauserRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqPauserRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqPauserRemoved represents a PauserRemoved event raised by the Rfq contract.
type RfqPauserRemoved struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPauserRemoved is a free log retrieval operation binding the contract event 0xcd265ebaf09df2871cc7bd4133404a235ba12eff2041bb89d9c714a2621c7c7e.
//
// Solidity: event PauserRemoved(address account)
func (_Rfq *RfqFilterer) FilterPauserRemoved(opts *bind.FilterOpts) (*RfqPauserRemovedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "PauserRemoved")
	if err != nil {
		return nil, err
	}
	return &RfqPauserRemovedIterator{contract: _Rfq.contract, event: "PauserRemoved", logs: logs, sub: sub}, nil
}

// WatchPauserRemoved is a free log subscription operation binding the contract event 0xcd265ebaf09df2871cc7bd4133404a235ba12eff2041bb89d9c714a2621c7c7e.
//
// Solidity: event PauserRemoved(address account)
func (_Rfq *RfqFilterer) WatchPauserRemoved(opts *bind.WatchOpts, sink chan<- *RfqPauserRemoved) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "PauserRemoved")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqPauserRemoved)
				if err := _Rfq.contract.UnpackLog(event, "PauserRemoved", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParsePauserRemoved is a log parse operation binding the contract event 0xcd265ebaf09df2871cc7bd4133404a235ba12eff2041bb89d9c714a2621c7c7e.
//
// Solidity: event PauserRemoved(address account)
func (_Rfq *RfqFilterer) ParsePauserRemoved(log types.Log) (*RfqPauserRemoved, error) {
	event := new(RfqPauserRemoved)
	if err := _Rfq.contract.UnpackLog(event, "PauserRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqRefundInitiatedIterator is returned from FilterRefundInitiated and is used to iterate over the raw logs and unpacked data for RefundInitiated events raised by the Rfq contract.
type RfqRefundInitiatedIterator struct {
	Event *RfqRefundInitiated // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqRefundInitiatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqRefundInitiated)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqRefundInitiated)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqRefundInitiatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqRefundInitiatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqRefundInitiated represents a RefundInitiated event raised by the Rfq contract.
type RfqRefundInitiated struct {
	Hash [32]byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterRefundInitiated is a free log retrieval operation binding the contract event 0x7cdd4403cff3a09d96c1ffe4ad1cc5c195e9053463a55edfc2944644ec022118.
//
// Solidity: event RefundInitiated(bytes32 hash)
func (_Rfq *RfqFilterer) FilterRefundInitiated(opts *bind.FilterOpts) (*RfqRefundInitiatedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "RefundInitiated")
	if err != nil {
		return nil, err
	}
	return &RfqRefundInitiatedIterator{contract: _Rfq.contract, event: "RefundInitiated", logs: logs, sub: sub}, nil
}

// WatchRefundInitiated is a free log subscription operation binding the contract event 0x7cdd4403cff3a09d96c1ffe4ad1cc5c195e9053463a55edfc2944644ec022118.
//
// Solidity: event RefundInitiated(bytes32 hash)
func (_Rfq *RfqFilterer) WatchRefundInitiated(opts *bind.WatchOpts, sink chan<- *RfqRefundInitiated) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "RefundInitiated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqRefundInitiated)
				if err := _Rfq.contract.UnpackLog(event, "RefundInitiated", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseRefundInitiated is a log parse operation binding the contract event 0x7cdd4403cff3a09d96c1ffe4ad1cc5c195e9053463a55edfc2944644ec022118.
//
// Solidity: event RefundInitiated(bytes32 hash)
func (_Rfq *RfqFilterer) ParseRefundInitiated(log types.Log) (*RfqRefundInitiated, error) {
	event := new(RfqRefundInitiated)
	if err := _Rfq.contract.UnpackLog(event, "RefundInitiated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqRefundedIterator is returned from FilterRefunded and is used to iterate over the raw logs and unpacked data for Refunded events raised by the Rfq contract.
type RfqRefundedIterator struct {
	Event *RfqRefunded // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqRefundedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqRefunded)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqRefunded)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqRefundedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqRefundedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqRefunded represents a Refunded event raised by the Rfq contract.
type RfqRefunded struct {
	Hash     [32]byte
	RefundTo common.Address
	SrcToken common.Address
	Amount   *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterRefunded is a free log retrieval operation binding the contract event 0x2e0668a62a5f556368dca9c7113e20f2852c05155548243804bf714ce72b25a6.
//
// Solidity: event Refunded(bytes32 hash, address refundTo, address srcToken, uint256 amount)
func (_Rfq *RfqFilterer) FilterRefunded(opts *bind.FilterOpts) (*RfqRefundedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "Refunded")
	if err != nil {
		return nil, err
	}
	return &RfqRefundedIterator{contract: _Rfq.contract, event: "Refunded", logs: logs, sub: sub}, nil
}

// WatchRefunded is a free log subscription operation binding the contract event 0x2e0668a62a5f556368dca9c7113e20f2852c05155548243804bf714ce72b25a6.
//
// Solidity: event Refunded(bytes32 hash, address refundTo, address srcToken, uint256 amount)
func (_Rfq *RfqFilterer) WatchRefunded(opts *bind.WatchOpts, sink chan<- *RfqRefunded) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "Refunded")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqRefunded)
				if err := _Rfq.contract.UnpackLog(event, "Refunded", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseRefunded is a log parse operation binding the contract event 0x2e0668a62a5f556368dca9c7113e20f2852c05155548243804bf714ce72b25a6.
//
// Solidity: event Refunded(bytes32 hash, address refundTo, address srcToken, uint256 amount)
func (_Rfq *RfqFilterer) ParseRefunded(log types.Log) (*RfqRefunded, error) {
	event := new(RfqRefunded)
	if err := _Rfq.contract.UnpackLog(event, "Refunded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqRfqContractsUpdatedIterator is returned from FilterRfqContractsUpdated and is used to iterate over the raw logs and unpacked data for RfqContractsUpdated events raised by the Rfq contract.
type RfqRfqContractsUpdatedIterator struct {
	Event *RfqRfqContractsUpdated // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqRfqContractsUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqRfqContractsUpdated)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqRfqContractsUpdated)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqRfqContractsUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqRfqContractsUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqRfqContractsUpdated represents a RfqContractsUpdated event raised by the Rfq contract.
type RfqRfqContractsUpdated struct {
	ChainIds           []uint64
	RemoteRfqContracts []common.Address
	Raw                types.Log // Blockchain specific contextual infos
}

// FilterRfqContractsUpdated is a free log retrieval operation binding the contract event 0xb4739c640c5970d8ce88b6c31f3706099efca660e282d47b0a267a0bb572d8b7.
//
// Solidity: event RfqContractsUpdated(uint64[] chainIds, address[] remoteRfqContracts)
func (_Rfq *RfqFilterer) FilterRfqContractsUpdated(opts *bind.FilterOpts) (*RfqRfqContractsUpdatedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "RfqContractsUpdated")
	if err != nil {
		return nil, err
	}
	return &RfqRfqContractsUpdatedIterator{contract: _Rfq.contract, event: "RfqContractsUpdated", logs: logs, sub: sub}, nil
}

// WatchRfqContractsUpdated is a free log subscription operation binding the contract event 0xb4739c640c5970d8ce88b6c31f3706099efca660e282d47b0a267a0bb572d8b7.
//
// Solidity: event RfqContractsUpdated(uint64[] chainIds, address[] remoteRfqContracts)
func (_Rfq *RfqFilterer) WatchRfqContractsUpdated(opts *bind.WatchOpts, sink chan<- *RfqRfqContractsUpdated) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "RfqContractsUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqRfqContractsUpdated)
				if err := _Rfq.contract.UnpackLog(event, "RfqContractsUpdated", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseRfqContractsUpdated is a log parse operation binding the contract event 0xb4739c640c5970d8ce88b6c31f3706099efca660e282d47b0a267a0bb572d8b7.
//
// Solidity: event RfqContractsUpdated(uint64[] chainIds, address[] remoteRfqContracts)
func (_Rfq *RfqFilterer) ParseRfqContractsUpdated(log types.Log) (*RfqRfqContractsUpdated, error) {
	event := new(RfqRfqContractsUpdated)
	if err := _Rfq.contract.UnpackLog(event, "RfqContractsUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqSrcDepositedIterator is returned from FilterSrcDeposited and is used to iterate over the raw logs and unpacked data for SrcDeposited events raised by the Rfq contract.
type RfqSrcDepositedIterator struct {
	Event *RfqSrcDeposited // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqSrcDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqSrcDeposited)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqSrcDeposited)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqSrcDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqSrcDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqSrcDeposited represents a SrcDeposited event raised by the Rfq contract.
type RfqSrcDeposited struct {
	Hash               [32]byte
	Detail             RFQQuote
	SrcRecipient       common.Address
	SubmissionDeadline uint64
	Raw                types.Log // Blockchain specific contextual infos
}

// FilterSrcDeposited is a free log retrieval operation binding the contract event 0xf540b19255a5c60a71a508bc7b079957ecabf5b2c16cd7ad708a94417dd16b5e.
//
// Solidity: event SrcDeposited(bytes32 hash, (uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) detail, address srcRecipient, uint64 submissionDeadline)
func (_Rfq *RfqFilterer) FilterSrcDeposited(opts *bind.FilterOpts) (*RfqSrcDepositedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "SrcDeposited")
	if err != nil {
		return nil, err
	}
	return &RfqSrcDepositedIterator{contract: _Rfq.contract, event: "SrcDeposited", logs: logs, sub: sub}, nil
}

// WatchSrcDeposited is a free log subscription operation binding the contract event 0xf540b19255a5c60a71a508bc7b079957ecabf5b2c16cd7ad708a94417dd16b5e.
//
// Solidity: event SrcDeposited(bytes32 hash, (uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) detail, address srcRecipient, uint64 submissionDeadline)
func (_Rfq *RfqFilterer) WatchSrcDeposited(opts *bind.WatchOpts, sink chan<- *RfqSrcDeposited) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "SrcDeposited")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqSrcDeposited)
				if err := _Rfq.contract.UnpackLog(event, "SrcDeposited", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSrcDeposited is a log parse operation binding the contract event 0xf540b19255a5c60a71a508bc7b079957ecabf5b2c16cd7ad708a94417dd16b5e.
//
// Solidity: event SrcDeposited(bytes32 hash, (uint64,address,uint256,uint64,address,uint256,uint64,uint64,address,address,address,address) detail, address srcRecipient, uint64 submissionDeadline)
func (_Rfq *RfqFilterer) ParseSrcDeposited(log types.Log) (*RfqSrcDeposited, error) {
	event := new(RfqSrcDeposited)
	if err := _Rfq.contract.UnpackLog(event, "SrcDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqSrcReleasedIterator is returned from FilterSrcReleased and is used to iterate over the raw logs and unpacked data for SrcReleased events raised by the Rfq contract.
type RfqSrcReleasedIterator struct {
	Event *RfqSrcReleased // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqSrcReleasedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqSrcReleased)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqSrcReleased)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqSrcReleasedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqSrcReleasedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqSrcReleased represents a SrcReleased event raised by the Rfq contract.
type RfqSrcReleased struct {
	Hash         [32]byte
	SrcRecipient common.Address
	SrcToken     common.Address
	Amount       *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterSrcReleased is a free log retrieval operation binding the contract event 0xf29b32a17c591b8b3b1216ce0ffb67c07f3478e99b50c5ccf8602878b1ee6376.
//
// Solidity: event SrcReleased(bytes32 hash, address srcRecipient, address srcToken, uint256 amount)
func (_Rfq *RfqFilterer) FilterSrcReleased(opts *bind.FilterOpts) (*RfqSrcReleasedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "SrcReleased")
	if err != nil {
		return nil, err
	}
	return &RfqSrcReleasedIterator{contract: _Rfq.contract, event: "SrcReleased", logs: logs, sub: sub}, nil
}

// WatchSrcReleased is a free log subscription operation binding the contract event 0xf29b32a17c591b8b3b1216ce0ffb67c07f3478e99b50c5ccf8602878b1ee6376.
//
// Solidity: event SrcReleased(bytes32 hash, address srcRecipient, address srcToken, uint256 amount)
func (_Rfq *RfqFilterer) WatchSrcReleased(opts *bind.WatchOpts, sink chan<- *RfqSrcReleased) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "SrcReleased")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqSrcReleased)
				if err := _Rfq.contract.UnpackLog(event, "SrcReleased", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSrcReleased is a log parse operation binding the contract event 0xf29b32a17c591b8b3b1216ce0ffb67c07f3478e99b50c5ccf8602878b1ee6376.
//
// Solidity: event SrcReleased(bytes32 hash, address srcRecipient, address srcToken, uint256 amount)
func (_Rfq *RfqFilterer) ParseSrcReleased(log types.Log) (*RfqSrcReleased, error) {
	event := new(RfqSrcReleased)
	if err := _Rfq.contract.UnpackLog(event, "SrcReleased", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqTreasuryAddrUpdatedIterator is returned from FilterTreasuryAddrUpdated and is used to iterate over the raw logs and unpacked data for TreasuryAddrUpdated events raised by the Rfq contract.
type RfqTreasuryAddrUpdatedIterator struct {
	Event *RfqTreasuryAddrUpdated // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqTreasuryAddrUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqTreasuryAddrUpdated)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqTreasuryAddrUpdated)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqTreasuryAddrUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqTreasuryAddrUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqTreasuryAddrUpdated represents a TreasuryAddrUpdated event raised by the Rfq contract.
type RfqTreasuryAddrUpdated struct {
	TreasuryAddr common.Address
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterTreasuryAddrUpdated is a free log retrieval operation binding the contract event 0xb17659014001857e7557191ad74dc9e967b181eaed0895975325e3848debbc42.
//
// Solidity: event TreasuryAddrUpdated(address treasuryAddr)
func (_Rfq *RfqFilterer) FilterTreasuryAddrUpdated(opts *bind.FilterOpts) (*RfqTreasuryAddrUpdatedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "TreasuryAddrUpdated")
	if err != nil {
		return nil, err
	}
	return &RfqTreasuryAddrUpdatedIterator{contract: _Rfq.contract, event: "TreasuryAddrUpdated", logs: logs, sub: sub}, nil
}

// WatchTreasuryAddrUpdated is a free log subscription operation binding the contract event 0xb17659014001857e7557191ad74dc9e967b181eaed0895975325e3848debbc42.
//
// Solidity: event TreasuryAddrUpdated(address treasuryAddr)
func (_Rfq *RfqFilterer) WatchTreasuryAddrUpdated(opts *bind.WatchOpts, sink chan<- *RfqTreasuryAddrUpdated) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "TreasuryAddrUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqTreasuryAddrUpdated)
				if err := _Rfq.contract.UnpackLog(event, "TreasuryAddrUpdated", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTreasuryAddrUpdated is a log parse operation binding the contract event 0xb17659014001857e7557191ad74dc9e967b181eaed0895975325e3848debbc42.
//
// Solidity: event TreasuryAddrUpdated(address treasuryAddr)
func (_Rfq *RfqFilterer) ParseTreasuryAddrUpdated(log types.Log) (*RfqTreasuryAddrUpdated, error) {
	event := new(RfqTreasuryAddrUpdated)
	if err := _Rfq.contract.UnpackLog(event, "TreasuryAddrUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RfqUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the Rfq contract.
type RfqUnpausedIterator struct {
	Event *RfqUnpaused // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RfqUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RfqUnpaused)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RfqUnpaused)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RfqUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RfqUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RfqUnpaused represents a Unpaused event raised by the Rfq contract.
type RfqUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Rfq *RfqFilterer) FilterUnpaused(opts *bind.FilterOpts) (*RfqUnpausedIterator, error) {

	logs, sub, err := _Rfq.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &RfqUnpausedIterator{contract: _Rfq.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Rfq *RfqFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *RfqUnpaused) (event.Subscription, error) {

	logs, sub, err := _Rfq.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RfqUnpaused)
				if err := _Rfq.contract.UnpackLog(event, "Unpaused", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseUnpaused is a log parse operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Rfq *RfqFilterer) ParseUnpaused(log types.Log) (*RfqUnpaused, error) {
	event := new(RfqUnpaused)
	if err := _Rfq.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
