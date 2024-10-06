# Unified Deployment Configuration

## Servers

### Bootstrap a Server

- Create a server instance on Hetzner Cloud (making sure to add an SSH key)
- Set up Nix on the server using [nixos-infect], preferably using the provided cloud-init expression
- SSH into the server and copy the contents of `/etc/nixos/*.nix` into `//servers/${hostname}/`,
  importing them in `//servers/${hostname}/default.nix`
- Deploy the server using `deploy -k .#${hostname} --hostname ${ip_addr}`, filling in the IP address
  of the server since it won't be accessible by hostname yet

### Deploy a Server

- Deploy from inside the devShell with `deploy -k .#${hostname}`

> To bootstrap remote builds from `aarch64-darwin` to `aarch64-linux`, you might have to run one of
> the two following commands:
>
> ``` console
> $ sudo deploy -k .#${hostname} -- --builders 'ssh-ng://root@${hostname} aarch64-linux'
> $ sudo nix build .#nixosConfigurations.${hostname}.config.system.build.toplevel --builders 'ssh://root@${hostname} aarch64-linux'
> ```
>
> The second one is likely to take a lot longer (and beware `/result` symlinks owned by `root` being
> left around).
>
> If you run into issues with host key verification, you might have to `ssh-keyscan` the hostname
> and add the machine's public key(s) to _`root`'s known_hosts file_.

[nixos-infect]: https://github.com/elitak/nixos-infect
