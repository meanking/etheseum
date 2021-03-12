//SPDX-License-Identifier: MIT
pragma solidity 0.7.3;
pragma experimental ABIEncoderV2;

import "../interfaces/IRegistry.sol";
import "../interfaces/IGasToken.sol";
import "../interfaces/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Registry related helper functions
 */
contract RegistryHelper {

    /**
     * @dev address registry of system, stores logic and wallet addresses
     */
    address public registry;

    /**
     * @dev Throws if the logic is not authorised
     */
    modifier logicAuth(address logicAddr) {
        require(logicAddr != address(0), "logic-proxy-address-required");
        require(IRegistry(registry).logic(logicAddr), "logic-not-authorised");
        _;
    }
}

/**
 * @title User Auth
 */
contract UserAuth is RegistryHelper {

    /**
     * @dev store allowed addresses to use the smart wallet
     */
    mapping(address => bool) public isDelegate;

    /**
     * @dev store user's transaction count
     */
    uint public nonce;

    /**
     * @dev Checks if called by owner or contract itself
     */
    modifier auth {
        require(
            isDelegate[msg.sender] || msg.sender == address(this),
            "permission-denied"
        );
        _;
    }

    /**
     * @dev Adds a new address that can control the smart wallet
     */
    function addDelegate(address newDelegate) external auth {
        isDelegate[newDelegate] = true;
    }
}

/**
 * @title User Owned Contract Wallet
 */
contract SmartWallet is UserAuth {
    using SafeMath for uint256;
    
    event LogMint(address erc20, uint256 tokenAmt, address owner);
    event LogRedeem(address erc20, uint256 tokenAmt, address owner);
    event LogDeposit(address erc20, uint256 tokenAmt);
    event LogWithdraw(address erc20, uint256 tokenAmt);

    IGasToken chi;

    /**
     * @dev sets the "address registry", owner's last activity, owner's active period and initial owner
     */
    function initialize(address _registry, address _user) public {
        require(registry == address(0), "ALREADY INITIALIZED");
        require(_user != address(0), "ZERO ADDRESS");
        registry = _registry;
        isDelegate[_user] = true;
        chi = IGasToken(0x0000000000004946c0e9F43F4Dee607b0eF1fA1c);
    }

    /**
        @dev calculates used gas and burns CHI gas tokens accordingly
     */
    modifier discountCHI(bool shouldBurn) {
        uint256 gasStart = gasleft();
        _;

        if (shouldBurn) {
            uint256 gasSpent = gasStart - gasleft();

            uint256 tokensToBurn = (21000 +
                gasSpent +
                16 *
                msg.data.length +
                14154) / 41947;

            //if the user has CHI on his smart wallet, burn from here...
            if (chi.balanceOf(address(this)) > 0)
                chi.freeUpTo(tokensToBurn);
                //if not, try to burn from the users own wallet
            else chi.freeFromUpTo(msg.sender, tokensToBurn);
        }
    }

    /**
        @dev internal function in charge of executing an action
        @dev checks with registry if the target address is allowed to be called
     */
    function _execute(address _target, bytes memory _data)
        internal
        logicAuth(_target)
    {
        require(_target != address(0), "target-invalid");
        assembly {
            let succeeded := delegatecall(
                gas(),
                _target,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    let size := returndatasize()
                    returndatacopy(0x00, 0x00, size)
                    revert(0x00, size)
                }
        }
    }

    /**
        @notice main function of the wallet
        @dev executes multiple delegate calls using the internal _execute fx
            burns CHI tokens when shouldBurn is true
        @param targets address array of the logic contracts to use
        @param datas bytes array of the encoded function calls
        @param shouldBurn users decides is they want to burn CHI tokens or not
     */
    function execute(
        address[] calldata targets,
        bytes[] calldata datas,
        bool shouldBurn
    ) external payable auth discountCHI(shouldBurn) {
        for (uint256 i = 0; i < targets.length; i++) {
            _execute(targets[i], datas[i]);
        }
    }

    function getHash(bytes memory data) public view returns(bytes32){
        return keccak256(abi.encodePacked(address(this), nonce, data));
    }

    function executeMetaTransaction(bytes memory sign, bytes memory data) public {
        bytes32 _hash = getHash(data);
        require(isDelegate[address(recover(_hash,sign))], "Invalid Signer");
        address target =  address(this);

        (bool success,) = target.call(data);
        require(success);

        nonce = nonce.add(1);
    }

    function recover(bytes32 hash, bytes memory signature) public pure returns (address) {
        // Check the signature length
        if (signature.length != 65) {
            revert("ECDSA: invalid signature length");
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert("ECDSA: invalid signature 's' value");
        }

        if (v != 27 && v != 28) {
            revert("ECDSA: invalid signature 'v' value");
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)), v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }


    /**
        @dev allow ether deposits
     */
    receive() external payable {}
}
