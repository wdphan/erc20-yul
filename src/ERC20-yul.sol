// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.15;

/// @title ERC20 Yul
/// @dev This contract implements the ERC20 token standard in Yul.
/// @author William Phan
/// @notice ERC20 token contract

// used in name() function
/// @dev Length is 3 in hex string
bytes32 constant nameLength = 0x0000000000000000000000000000000000000000000000000000000000000009;

/// @dev "Yul Token" in hex string
bytes32 constant nameData = 0x79756c20746f6b656e0000000000000000000000000000000000000000000000;

/// @dev Big number in hex string
uint256 constant maxUint256 = 0x0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

/// @dev Symbol Length in hex string
bytes32 constant symbolLength = 0x0000000000000000000000000000000000000000000000000000000000000003;

// @dev "YUL" in hex string
bytes32 constant symbolData = 0x59554c0000000000000000000000000000000000000000000000000000000000;

/// @dev `bytes(keccak256('InsufficientBalance()"))` in hex string
bytes32 constant insufficientBalanceSelector = 0xf4d678b800000000000000000000000000000000000000000000000000000000;

/// @dev `bytes(keccak256('InsufficientAllowance(address, address"))` in hex string
bytes32 constant insufficientAllowanceSelector = 0xf180d8f900000000000000000000000000000000000000000000000000000000;

/// @dev `Transfer(address, address, uint256)` in hex string
bytes32 constant transferHash = 0x7472616e7366657228616464726573732c20616464726573732c2075696e7400;

/// @dev `Approval(address, address, uint256)` in hex string
bytes32 constant approvalHash = 0x7472616e7366657228616464726573732c20616464726573732c2075696e7400;

/// @dev This error is thrown when a user has insufficient balance to complete a transaction
error InsufficientBalance();

/// @dev This error is thrown when a user has insufficient allowance to complete a transaction
/// @param owner The owner of the token.
/// @param spender The spender of the token.
error InsufficientAllowance(address owner, address spender);

contract ERC20 {
    event Transfer(address indexed sender, address indexed receiver, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    // owner -> balance
    // slot 0x00
    mapping(address => uint256) internal _balances;
    // keccak256(spender, keccek256(owner, slot)))
    // owner -> spender -> allowance
    // slot 0x01
    mapping(address => mapping(address => uint256)) internal _allowances;
    // slot 0x02
    uint256 internal _totalSupply;

    constructor () {
        assembly {
            // store the caller
            mstore(0x00, caller())
            mstore(0x20, 0x00)
            // the slot for balances
            let slot := keccak256(0x00, 0x40)
            // at the slot, store the total supply
            sstore(slot, maxUint256)

            sstore(0x02, maxUint256)

            // store the amount in mem
            mstore(0x00, maxUint256)
            // log event
            log3(0x00, 0x20, transferHash, 0x00, caller())
            // we don't return the contract bc the constructer 
            // returns the bytecode at the end of its execution
        }
    }

    /// @notice store the token name 
    /// @return the token name as string
    function name() public pure returns (string memory) {
        assembly {
            // load the mem pointer from memory
            // if you write to 3 or more slots, write to the mem ptr
            let memptr := mload(0x40)
            // from the memptr, store 32 bytes (length) at the pointer
            mstore(memptr, 0x20)
            // offset by 32 bytes (0x20), store the nameLength
            mstore(add(memptr, 0x20), nameLength)
            // store the nameData
            mstore(add(memptr, 0x40), nameData)
            // ocupies 3 slots - 0x60
            return(memptr, 0x60)
        }
    }

    /// @notice stores the token symbol
    /// @return the total supply as string
    function symbol() public pure returns (string memory) {
        assembly {
            // load the mem ptr from memory
            // if you write to 3 or more slots, write to the mem ptr
            let memptr := mload(0x40)
            // from the memptr, store 32 bytes (length) at the pointer
            mstore(memptr, 0x20)
            // offset by 32 bytes (0x20), store the symbolLength
            mstore(add(memptr, 0x20), symbolLength)
            // offset by 64 bytes (0x40), store the symbolData
            mstore(add(memptr, 0x40), symbolData)
            // ocupies 3 slots - 0x60
            return(memptr, 0x60)
        }
    }

    function decimals() public pure returns (uint8) {
        assembly {
            mstore(0, 18)
            return(0x0, 0x20)
        }
    }

    /// @notice stores total token supply
    /// @return the total supply as uint
    function totalSupply() public view returns (uint256) {
        assembly {
            // load from slot 3
            mstore(0x00, sload(0x02))
            return(0x00, 0x20)
        }
    }

    /// @notice stores total token supply
    /// @param user address The amount of tokens of user account
    /// @return the total supply as uint
    function balanceOf(address user) public view returns (uint256) {
        assembly {
            // first 4 bytes are function selector, then next
            // 32 bytes would be the address
            // stores what ever is in calldata starting after 4 bytes at slot 0
            mstore(0x00, calldataload(4))
            // at 0x20, store 0
            mstore(0x20, 0x00)
            // load the hash of the pointer mem and size and store it at 0x0
            mstore(0x00, sload(keccak256(0x00, 0x40)))
            return(0x00, 0x20)
        }
    }

    /// @notice transfer tokens to receiver
    /// @param receiver address The amount of tokens transferred
    /// @param value the amount of tokens to transfer
    /// @return boolean true if the transfer sucessfully completed
    function transfer(address receiver, uint256 value) public returns (bool) {
        assembly {
            // load the mem ptr from memory
            // if you write to 3 or more slots, write to the mem ptr
            let memptr := mload(0x40)
            // from the memptr, store the caller address
            mstore(memptr, caller())
            // at the memptr + 32 bytes, we store the balance slot - 0
            mstore(add(memptr, 0x20), 0x00)
            let callerBalanceSlot := keccak256(memptr, 0x40)
            // hash the memptr (start) and the size (0x40) to load to storage
            let callerBalance := sload(keccak256(memptr, 0x40))
            // if caller balance is less than the value of the transfer...
            if  lt(callerBalance, value) {
                mstore(0x00, insufficientBalanceSelector)
                // revert at the pointer and size in mem, could use 0x20 for size
                revert(0x00, 0x04)
            }

            // revert is the caller is the recever
            if eq(caller(), receiver) {
                // ugly revert
                revert(0x00, 0x00)
            }

            // we know caller balace is sufficient
            // subtract the value from the caller balance
            let newCallerBalance := sub(callerBalance, value)

            // dont need the two slots anymore so below overwrites them
            mstore(memptr, receiver)
            mstore(add(memptr, 0x20), 0x00)

            let receiverBalanceSlot := keccak256(memptr, 0x40)

            let receiverBalance := sload(receiverBalanceSlot)
            
            // add the value to the receiver balance
            let newReceiverBalance := add(receiverBalance, value)

            // balances are set up, so now we store them
            sstore(callerBalanceSlot, newCallerBalance)
            sstore(receiverBalanceSlot, newReceiverBalance)

            // event log
            mstore(0x00, value)
            // 2 indexed args + event sig = 3 args so log3
            // pointer in mem starts at 0, size is 32 bytes
            log3(0x00, 0x20, transferHash, caller(), receiver)

            // store at slot 0, 0x01. This is the true value
            mstore(0x00, 0x01)
            // return the boolean above
            return(0x00, 0x20)
        }
    }


        function allowance(address owner, address spender) public view returns (uint256) {
            assembly {
                // keccak256(spender, keccek256(owner, slot)))
                mstore(0x00, owner)
                mstore(0x20, 0x01)
                // form first slot
                let innerHash := keccak256(0x00, 0x40)

                mstore(0x00, spender)
                mstore(0x20, innerHash)

                // form second slot
                let allowanceSlot := keccak256(0x00, 0x40)
                // load from the slot
                let allowanceValue := sload(allowanceSlot)
                // put the slot into mem
                mstore(0x00, allowanceValue)
                // return it
                return(0x00, 0x20)
        }
    }

    function approve(address spender, uint256 amount) public returns (bool) {
         assembly {
                // keccak256(spender, keccek256(owner, slot)))
                mstore(0x00, caller())
                mstore(0x20, 0x01)
                // form first slot
                let innerHash := keccak256(0x00, 0x40)

                mstore(0x00, spender)
                mstore(0x20, innerHash)

                // form second slot
                let allowanceSlot := keccak256(0x00, 0x40)
                
                sstore(allowanceSlot, amount)
                // store amount in storage
                mstore(0x00, amount)
                log3(0x00, 0x20, approvalHash, caller(), spender)
                mstore(0x00, 0x01)
                return(0x00, 0x20)
        }
    }

    /// @notice transfer tokens
    /// @param sender address of the person transferring tokens
    /// @param receiver address of the person receiving tokens
    /// @return boolean true if the transfer sucessfully completed
    function transferFrom(address sender, address receiver, uint256 amount) public returns (bool) {
        assembly {
                let memptr := mload(0x40)
                // keccak256(spender, keccek256(owner, slot)))
                mstore(0x00, sender)
                mstore(0x20, 0x01)
                // form first slot
                let innerHash := keccak256(0x00, 0x40)

                mstore(0x00, caller())
                mstore(0x20, innerHash)

                // form second slot
                let allowanceSlot := keccak256(0x00, 0x40)

                let callerAllowance := sload(allowanceSlot)

                if lt(callerAllowance, amount) {
                    mstore(memptr, insufficientAllowanceSelector)
                    mstore(add(memptr, 0x04), sender)
                    mstore(add(memptr, 0x24), caller())
                    revert(memptr, 0x44)
                }

                // if the caller allowance is less than the max huge number we set,
                // then we decrease the caller allowance and store it in the allowance slot
                if lt(callerAllowance, maxUint256 ) {
                    sstore(allowanceSlot, sub(callerAllowance, amount))
                }

                // from the memptr, store the sender address
                mstore(memptr, sender)
                // at the memptr + 32 bytes, we store the balance slot - 0
                mstore(add(memptr, 0x20), 0x00)
                let senderBalanceSlot := keccak256(memptr, 0x40)
                // hash the memptr (start) and the size (0x40) to load to storage
                let senderBalance := sload(keccak256(memptr, 0x40))
                // if sender balance is less than the value of the transfer...
                if  lt(senderBalance, amount) {
                    mstore(0x00, insufficientBalanceSelector)
                    // revert at the pointer and size in mem, could use 0x20 for size
                    revert(0x00, 0x04)
                }

                sstore(senderBalanceSlot, add(senderBalance, amount))

                // from the memptr, store the receiver address
                mstore(memptr, receiver)
                // at the memptr + 32 bytes, we store the balance slot - 0
                mstore(add(memptr, 0x20), 0x00)
                let receiverBalanceSlot := keccak256(memptr, 0x40)
                // hash the memptr (start) and the size (0x40) to load to storage
                let receiverBalance := sload(keccak256(memptr, 0x40))
                // if receiver balance is less than the value of the transfer...

                sstore(receiverBalanceSlot, add(receiverBalance, amount))

                mstore(0x00, amount)
                log3(0x00, 0x20, transferHash, sender, receiver)

                // store true
                mstore(0x00, 0x01)
                // return boolean true
                return(0x00, 0x20)
        }
    }
}