import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('social_accounts')
export class SocialAccount {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column()
  projectId: string;

  @Column()
  platform: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok' | 'facebook';

  @Column()
  accountName: string;

  @Column({ nullable: true })
  accountAvatar: string;

  @Column()
  status: 'connected' | 'disconnected' | 'error';

  @Column()
  authType: 'oauth' | 'token' | 'bot_token';

  @Column()
  accessTokenEncrypted: string;

  @Column({ nullable: true })
  refreshTokenEncrypted: string;

  @Column({ nullable: true })
  tokenExpiresAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
