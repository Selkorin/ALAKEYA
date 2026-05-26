import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('social_agents')
export class SocialAgent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  socialAccountId: string;

  @Column()
  agentName: string;

  @Column()
  agentRole: string;

  @Column('text')
  toneOfVoice: string;

  @Column('json')
  brandRules: Record<string, any>;

  @Column('json')
  contentRules: Record<string, any>;

  @Column({ default: false })
  autoPublishEnabled: boolean;

  @Column({ default: true })
  approvalRequired: boolean;

  @Column({ default: 'claude' })
  aiProvider: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
