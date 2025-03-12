epic# [epicbox://](http://epicbox.io): An open transaction building protocol

[![Join the chat at https://gitter.im/vault713/epicbox](https://badges.gitter.im/vault713/epicbox.svg)](https://gitter.im/vault713/epicbox?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Introduction
[Epic](https://github.com/mimblewimble/epic) is a blockchain-powered cryptocurrency that is an implementation of the Mimblewimble protocol, with a focus on privacy and scalability. In Mimblewimble, transactions are interactive, requiring the Sender and Recipient to interact over a single round trip in order to build the transaction.

### What's Epicbox?

Epicbox provides a simple way for parties to exchange transaction slates as part of the interactive process of building a valid Epic transaction.

In order to communicate over the relay, each party has to be able to get pending slates from the relay from a dedicated address, and to post new slates to the relay to the other party's dedicated address. **The address is identified by each party's public key.**

## Transaction flow overview
Assuming Alice wants to send Bob 50 epic using the relay:
1. Alice creates a public/private key pair and an access signature to use as her dedicated address
2. Bob creates a public/private key pair and an access signature to use as his dedicated address
3. Bob sends Alice his public key
4. Alice creates a slate for sending 50 epics to Bob and posts it to Bob's address, identified by the public key in the previous step
5. Bob gets the slate from his address using his signature
6. Bob processes the slate and posts the response into Alice's address
7. Alice gets the slate from her address using her signature
8. Alice finalizes the transaction and broadcasts it to the Epic blockchain

## Functionality

* Written in Rust, Epicbox utilizes websockets to communicate with relay users.
* Relay server federation is supported, allowing you to run your own Epicbox server and be accessible as `publickey@yourdomain.com`.


## Integration instructions

Epicbox is free and open for anyone to use. For  instructions on how to integrate with your product or service, see the [relevant section in the documentation](docs/integration.md). You are also welcome to reach out to us at [hello@713.mw](mailto:hello@713.mw) or on [Gitter](https://gitter.im/vault713/epicbox) and we'll help with this.

## Privacy considerations

* **The relay does not store data.** Epicbox does not store any data on completed transactions by design, but it would be possible for a modified version of a relay to do so and as a result build a graph of activity between addresses. Federation means that a relay only sees transactions related to its own users.

* **Your IP is your responsibility.** When you communicate with a epicbox relay, you are exposing your IP to the relay. You can obfuscate your real IP address using services such as a VPN and/or TOR or i2p.

## License

Apache License v2.0.
